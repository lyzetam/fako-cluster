// Offline test for ../audit-policy.yaml using the API server's own audit
// policy loader and rule evaluator (k8s.io/apiserver, k3s v1.34 line).
//
//	cd docs/operations/k3s-audit/policytest && go run . ../audit-policy.yaml cases.yaml
//
// No cluster access. Exit status 1 if any case fails.
// Cases: Norbert's 34 (source "norbert") plus Mel's (source "mel").
// want "Metadata+" accepts Metadata or Request (recorded, body optional).
package main

import (
	"fmt"
	"os"

	"k8s.io/apiserver/pkg/audit/policy"
	"k8s.io/apiserver/pkg/authentication/user"
	"k8s.io/apiserver/pkg/authorization/authorizer"
	"sigs.k8s.io/yaml"
)

type tc struct {
	Source      string   `json:"source"`
	Name        string   `json:"name"`
	User        string   `json:"user"`
	SA          string   `json:"sa"` // "namespace/name": sets user and SA groups
	Groups      []string `json:"groups"`
	Verb        string   `json:"verb"`
	Namespace   string   `json:"ns"`
	Group       string   `json:"group"`
	Resource    string   `json:"res"`
	Subresource string   `json:"sub"`
	Path        string   `json:"path"` // non-resource URL
	Want        string   `json:"want"`
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("usage: go run . <audit-policy.yaml> <cases.yaml>")
		os.Exit(2)
	}
	p, err := policy.LoadPolicyFromFile(os.Args[1])
	if err != nil {
		fmt.Println("INVALID POLICY:", err)
		os.Exit(1)
	}
	fmt.Printf("policy OK: rules=%d omitStages=%v\n", len(p.Rules), p.OmitStages)
	raw, err := os.ReadFile(os.Args[2])
	if err != nil {
		panic(err)
	}
	var cases []tc
	if err := yaml.Unmarshal(raw, &cases); err != nil {
		panic(err)
	}
	ev := policy.NewPolicyRuleEvaluator(p)
	pass, bySrc := 0, map[string][2]int{}
	for _, t := range cases {
		u, g := t.User, t.Groups
		if t.SA != "" {
			var ns, n string
			for i := range t.SA {
				if t.SA[i] == '/' {
					ns, n = t.SA[:i], t.SA[i+1:]
				}
			}
			u = "system:serviceaccount:" + ns + ":" + n
			g = append([]string{"system:serviceaccounts", "system:serviceaccounts:" + ns, "system:authenticated"}, g...)
		}
		a := authorizer.AttributesRecord{User: &user.DefaultInfo{Name: u, Groups: g}, Verb: t.Verb}
		if t.Path != "" {
			a.Path = t.Path
		} else {
			a.ResourceRequest = true
			a.Namespace, a.APIGroup, a.Resource, a.Subresource = t.Namespace, t.Group, t.Resource, t.Subresource
		}
		got := string(ev.EvaluatePolicyRule(a).Level)
		ok := got == t.Want || (t.Want == "Metadata+" && (got == "Metadata" || got == "Request"))
		mark := "FAIL"
		s := bySrc[t.Source]
		s[1]++
		if ok {
			mark = "ok  "
			pass++
			s[0]++
		}
		bySrc[t.Source] = s
		fmt.Printf("%s [%-7s] %-48s got=%-9s want=%s\n", mark, t.Source, t.Name, got, t.Want)
	}
	for k, v := range bySrc {
		fmt.Printf("source %-7s %d/%d\n", k, v[0], v[1])
	}
	fmt.Printf("PASS %d/%d\n", pass, len(cases))
	if pass != len(cases) {
		os.Exit(1)
	}
}

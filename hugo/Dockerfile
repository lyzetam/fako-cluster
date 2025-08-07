# Build stage
FROM hugomods/hugo:exts-0.148.2 AS builder

# Install git
RUN apk add --no-cache git

WORKDIR /src

# Copy the Hugo configuration files
COPY config.toml .
COPY nginx.conf .

# Clone the main repository to get documentation
RUN git clone --depth 1 https://github.com/lyzetam/fako-cluster.git /tmp/fako-cluster && \
    mkdir -p content && \
    cp -r /tmp/fako-cluster/docs/* content/ && \
    rm -rf /tmp/fako-cluster

# Download the theme
RUN git clone --depth 1 https://github.com/google/docsy.git themes/docsy && \
    cd themes/docsy && \
    git submodule update --init --recursive

# Build the Hugo site
RUN hugo --minify --baseURL https://blog.landryzetam.net

# Runtime stage - using nginx to serve static files
FROM nginx:alpine

# Copy the built site from builder
COPY --from=builder /src/public /usr/share/nginx/html

# Copy custom nginx config if needed
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

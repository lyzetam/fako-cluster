resource "aws_secretsmanager_secret" "alpaca_credentials" {
  name                    = "alpaca-trading/api-credentials"
  description             = "Alpaca trading API credentials for quantum-trades"
  recovery_window_in_days = 7

  tags = {
    Environment = "production"
    Application = "quantum-trades"
    Service     = "alpaca"
  }
}

resource "aws_secretsmanager_secret_version" "alpaca_credentials" {
  secret_id = aws_secretsmanager_secret.alpaca_credentials.id
  secret_string = jsonencode({
    api_key    = "PLACEHOLDER_API_KEY_ROTATE_AFTER_DEPLOYMENT"
    api_secret = "PLACEHOLDER_API_SECRET_ROTATE_AFTER_DEPLOYMENT"
    base_url   = "https://paper-api.alpaca.markets"
  })
}

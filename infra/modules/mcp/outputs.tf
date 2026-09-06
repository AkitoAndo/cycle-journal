output "service_url" {
  value = trimsuffix(local.public_url, "/mcp")
}

output "mcp_url" {
  value = local.public_url
}

output "service_account_email" {
  value = google_service_account.mcp.email
}

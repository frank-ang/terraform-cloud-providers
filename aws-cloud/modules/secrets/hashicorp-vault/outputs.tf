output "hault_address" {
  value = local.hault_hostname
}

output dummy_saml_idp_basic_auth_user {
  value = var.dummy_saml_idp_basic_auth_user
}

output dummy_saml_idp_basic_auth_password {
  value = var.dummy_saml_idp_basic_auth_password
}

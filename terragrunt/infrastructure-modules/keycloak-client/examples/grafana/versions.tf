terraform {
  required_version = ">= 1.7.0"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.8.0"
    }
  }
}

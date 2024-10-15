terraform {
  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "0.0.55"  # Ensure this matches the latest version
    }
  }
}

provider "cloudsmith" {
  # USing OIDC
}

data "cloudsmith_organization" "my_org" {
  slug = "ciara-demo"  # Your organization slug
}

resource "cloudsmith_team" "dev_aerlingus" {
  organization = data.cloudsmith_organization.my_org.slug
  name         = "Dev-AerLingus"  # Name of the team
}

resource "cloudsmith_service" "aerlingus_service" {
  name         = "aerlingus-ci"
  organization = data.cloudsmith_organization.my_org.slug

  team {
    slug = cloudsmith_team.dev_aerlingus.slug  # Link the service to the Dev-AerLingus team
  }
}

resource "cloudsmith_repository" "aerlingus_nonprod" {
  description = "Non-production repository for Aer Lingus"
  name        = "aerlingus-nonprod"  # Non-production repository name
  namespace   = data.cloudsmith_organization.my_org.slug_perm
  slug        = "aerlingus-nonprod"  # Non-production repository slug
}

resource "cloudsmith_repository" "aerlingus_prod" {
  description = "Production repository for Aer Lingus"
  name        = "aerlingus-prod"  # Production repository name
  namespace   = data.cloudsmith_organization.my_org.slug_perm
  slug        = "aerlingus-prod"  # Production repository slug
}

resource "cloudsmith_repository_privileges" "nonprod_privileges" {
  organization = data.cloudsmith_organization.my_org.slug
  repository   = cloudsmith_repository.aerlingus_nonprod.slug

  service {
    privilege = "Write"  # Write access for the service account
    slug      = cloudsmith_service.aerlingus_service.slug
  }

  team {
    privilege = "Write"  # Write access for Dev-AerLingus team
    slug      = cloudsmith_team.dev_aerlingus.slug
  }
}

resource "cloudsmith_repository_privileges" "prod_privileges" {
  organization = data.cloudsmith_organization.my_org.slug
  repository   = cloudsmith_repository.aerlingus_prod.slug

  service {
    privilege = "Write"  # Write access for the service account
    slug      = cloudsmith_service.aerlingus_service.slug
  }

  team {
    privilege = "Read"  # Read access for Dev-AerLingus team
    slug      = cloudsmith_team.dev_aerlingus.slug
  }
}

resource "cloudsmith_repository_upstream" "pypi_upstream" {
  name          = "Python Package Index"
  namespace     = data.cloudsmith_organization.my_org.slug_perm
  repository    = cloudsmith_repository.aerlingus_nonprod.slug_perm  # Use non-prod for upstream
  upstream_type = "python"
  upstream_url  = "https://pypi.org"
  mode = "Cache and Proxy"
}

# New Vulnerability Policy for Production Repository
resource "cloudsmith_vulnerability_policy" "prod_vulnerability_policy" {
    name                    = "Aer Lingus Production Policy"
    description             = "Vulnerability policy for the Aer Lingus production repository"
    min_severity            = "Medium"  # Set the minimum severity level (adjust as needed)
    on_violation_quarantine = true
    allow_unknown_severity  = false
    package_query_string    = "repository:${cloudsmith_repository.aerlingus_prod.slug} AND format:python AND downloads:>50"  # Adjust the query as needed
    organization            = data.cloudsmith_organization.my_org.slug
}

resource "cloudsmith_oidc" "my_oidc" {
  namespace       = data.cloudsmith_organization.my_org.slug_perm
  name            = "Aerlingus OIDC"  # Name for the OIDC configuration
  enabled         = true
  provider_url    = "https://token.actions.githubusercontent.com"  # GitHub OIDC provider URL
  service_accounts = [cloudsmith_service.aerlingus_service.slug]  # Link the service account(s)

  claims = {
    "repository_owner" = "ciaracarey"  # Replace with the correct repository owner
  }
}

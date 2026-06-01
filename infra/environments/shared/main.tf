provider "google" {
  project = var.project_id
  region  = var.region
}

module "shared" {
  source = "../../modules/shared"

  project_id = var.project_id
  region     = var.region
}

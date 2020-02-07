variable "project" {}

variable "postgres_user" {
  default = "airflow"
}
variable "postgres_pw" {
  default = "airflow"
}

variable "region" {
  default = "europe-west3"
}

variable "zone" {
  default = "europe-west3-a"
}

provider "google" {
  version = "~> 3.7"
  project = "${var.project}"
  region = "${var.region}"
}

data "google_compute_network" "default" {
  project = "${var.project}"
  name    = "${var.network}"
}

resource "google_compute_global_address" "airflow-static-ip" {
  name = "airflow-static-ip"
}

resource "google_compute_disk" "airflow-redis-disk" {
  name  = "airflow-redis-disk"
  type  = "pd-ssd"
  size = "200"
  zone  = "${var.zone}"
}

resource "google_sql_database_instance" "airflow-db" {
  name = "airflow-db"
  database_version = "POSTGRES_11"
  region = "${var.region}"
  settings {
    tier = "db-g1-small"
  }
}

resource "google_sql_database" "airflow-schema" {
  name = "airflow"
  instance = "${google_sql_database_instance.airflow-db.name}"
}

resource "google_sql_user" "proxyuser" {
  name = "${var.postgres_user}"
  password = "${var.postgres_pw}"
  instance = "${google_sql_database_instance.airflow-db.name}"
  host = "cloudsqlproxy~%"
}

resource "google_container_cluster" "airflow-cluster" {
  name = "airflow-cluster"
  location = "${var.zone}"
  network = "${var.network}"
  subnetwork = "${var.subnet}"
  initial_node_count = "1"
  node_config {
    machine_type = "n1-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }
}

variable "name" { type = string, default = "moodle" }

output "database_name" {
  value = var.name
}
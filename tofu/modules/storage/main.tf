variable "storage_class" { type = string, default = "longhorn" }

output "storage_class" {
  value = var.storage_class
}
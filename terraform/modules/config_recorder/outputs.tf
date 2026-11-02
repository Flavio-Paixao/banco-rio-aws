output "recorder_name" {
  description = "Nome do gravador do Config"
  value       = aws_config_configuration_recorder.main.name
}

output "instance_public_ip" {
  value = aws_instance.lab_server.public_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_instance.lab_server.public_ip}"
}
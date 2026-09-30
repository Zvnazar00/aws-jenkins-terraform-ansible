output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}

output "inventory_file" {
  value = "${path.module}/../ansible/hosts.txt"
}
output "subnet_a_id" {
  description = "Subnet 'a' of the created VPC"
  value       = aws_subnet.a.id
}

output "subnet_b_id" {
  description = "Subnet 'b' of the created VPC"
  value       = aws_subnet.b.id
}

output "subnet_c_id" {
  description = "Subnet 'c' of the created VPC"
  value       = aws_subnet.c.id
}

output "vpc_id" {
  description = "Created VPC's ID"
  value       = aws_vpc.main.id
}


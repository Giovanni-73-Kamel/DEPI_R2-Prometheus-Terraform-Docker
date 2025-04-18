data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
resource "aws_key_pair" "prometheus_key" {
  key_name   = "prometheus-key"
  public_key = file("/home/giovanni-kamel/.ssh/id_ed25519.pub")

}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic and all outbound traffic"

  tags = {
    Name = "allow_ssh"
  }
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22

}

resource "aws_vpc_security_group_ingress_rule" "allow_prometheus_port" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 9090
  ip_protocol       = "tcp"
  to_port           = 9090
}
resource "aws_instance" "prometheus_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.prometheus_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  tags = {
    Name = "prometheus_server"
  }

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("/home/giovanni-kamel/.ssh/id_ed25519")
    host     = self.public_ip
  }
  provisioner "file" {
    source      = "./prometheus.yaml"
    destination = "/home/ubuntu/prometheus.yaml"
  }
  
  provisioner "remote-exec" {
    script = "install_docker.sh"
  }

}
output "prometheus_public_ip" {
  value = aws_instance.prometheus_server.public_ip
  description = "Public IP of the Prometheus server"
}

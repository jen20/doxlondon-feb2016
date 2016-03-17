provider "aws" {
    region = "us-west-2"
}

variable "consul_ami" {
}

variable "openvpn_ami" {
    default = "ami-4e57bb2e"
}

variable "key_name" {
    default = "doxlondonfeb2016"
}

module "vpc" {
    source = "modules/vpc"

    name = "Production"
    cidr = "10.0.0.0/16"
    private_subnets = "10.1.160.0/19,10.1.192.0/19,10.1.224.0/19"
    public_subnets = "10.1.0.0/21,10.1.8.0/21,10.1.16.0/21"
    availability_zones = "us-west-2a,us-west-2b,us-west-2c"
}

module "vpn" {
    source = "modules/vpn"

    vpc_id = "${module.vpc.vpc_id}"
    public_subnets = "${module.vpc.public_subnets}"
    ami = "${var.openvpn_ami}"
    key_name = "${var.key_name}"
}

module "consul" {
    source = "modules/consul"

    cluster_name = "Production"

    ami = "${var.consul_ami}"
    vpc_id = "${module.vpc.vpc_id}"
    subnets = "${module.vpc.private_subnets}"
    ingress_cidr_blocks = "0.0.0.0/0"

    key_name = "${var.key_name}"
    ami = "ami-7eb45a1e"
    instance_type = "t2.micro"
}

resource "aws_instance" "temp_bastion" {
    ami = "ami-f0091d91"
    instance_type = "t2.micro"

    subnet_id = "${element(split(",", module.vpc.public_subnets), 0)}"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
    key_name = "${var.key_name}"
}

resource "aws_security_group" "bastion" {
    name = "bastion-sg"
    description = "Security group for Bastion Instances"
    vpc_id = "${module.vpc.vpc_id}"

    tags {
        Name = "Bastion"
    }

    # SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # TCP All outbound traffic
    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "bastion_ip" {
    value = "${aws_instance.temp_bastion.public_ip}"
}

output "vpn_ip" {
    value = "${module.vpn.vpn_ip}"
}

output "vpn_setup_command" {
    value = "${format("ssh openvpnas@%s", module.vpn.vpn_ip)}"
}

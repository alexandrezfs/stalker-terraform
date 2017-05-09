output "elb_dns_name" {
  value = "${aws_elb.stalker.dns_name}"
}

output "ami_id" {
  value = "${data.aws_ami.image.id}"
}

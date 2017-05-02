output "elb_dns_name" {
  value = "${aws_elb.stalker.dns_name}"
}

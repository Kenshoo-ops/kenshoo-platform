output "compartment_id" {
  value = oci_identity_compartment.kenshoo.id
}

output "instance_public_ip" {
  value = one(oci_core_instance.k3s[*].public_ip)
}

output "ssh_command" {
  value = try("ssh -i ~/.ssh/kenshoo ubuntu@${oci_core_instance.k3s[0].public_ip}", "instance not created yet")
}

variables {
  owner                 = "hajar-mezouar"
  resource_group_name   = "hmezouarRG"
  app_service_plan_name = "plan-npr-prf2026"
  location              = "francecentral"

  tags = {
    owner = "hajar-mezouar"
  }
}
run "container_plan" {

  command = plan

  assert {
    condition     = module.container.fqdn != ""
    error_message = "Container Instance should expose an FQDN."
  }

}
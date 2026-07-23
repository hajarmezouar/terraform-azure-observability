variables {
  owner                 = "hajar-mezouar"
  resource_group_name   = "hmezouarRG"
  app_service_plan_name = "plan-npr-prf2026"
  location              = "francecentral"

  tags = {
    owner = "hajar-mezouar"
  }
}
run "app_service_plan" {

  command = plan

  assert {
    condition     = module.app_service.default_hostname != ""
    error_message = "App Service hostname should not be empty."
  }

}
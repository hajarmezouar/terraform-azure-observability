variables {
  owner                 = "hajar-mezouar"
  resource_group_name   = "hmezouarRG"
  app_service_plan_name = "plan-npr-prf2026"
  location              = "francecentral"

  tags = {
    owner = "hajar-mezouar"
  }
}
run "function_app_plan" {

  command = plan

  assert {
    condition     = module.function_app.default_hostname != ""
    error_message = "Function App hostname should not be empty."
  }

}
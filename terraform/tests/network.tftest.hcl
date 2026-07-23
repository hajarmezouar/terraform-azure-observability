variables {
  owner                 = "hajar-mezouar"
  resource_group_name   = "hmezouarRG"
  app_service_plan_name = "plan-npr-prf2026"
  location              = "francecentral"

  tags = {
    owner = "hajar-mezouar"
  }
}
run "network_plan" {

  command = plan

  assert {
    condition     = module.network.vnet_id != ""
    error_message = "Virtual Network should be created."
  }

  assert {
    condition     = module.network.subnet_frontend_id != ""
    error_message = "Frontend subnet should exist."
  }

  assert {
    condition     = module.network.subnet_backend_id != ""
    error_message = "Backend subnet should exist."
  }

}
variables {
  owner                 = "hajar-mezouar"
  resource_group_name   = "hmezouarRG"
  app_service_plan_name = "plan-npr-prf2026"
  location              = "francecentral"

  tags = {
    owner = "hajar-mezouar"
  }
}
run "storage_plan" {

  command = plan

  assert {
    condition     = module.storage.storage_account_name != ""
    error_message = "Storage Account name should not be empty."
  }

}
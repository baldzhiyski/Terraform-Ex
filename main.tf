terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.11.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "fc818fca-c67f-4e21-a59d-19fa30538e7f"
  features {
  }
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "hristoorg" {
  location = var.resource_group_location
  name     = "${var.resource_group_name}-${random_integer.ri.result}"
}

resource "azurerm_service_plan" "hristoasp" {
  name                = "${var.app_service_plan_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.hristoorg.name
  location            = azurerm_resource_group.hristoorg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "hristoalwa" {
  name                = "${var.app_service_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.hristoorg.name
  location            = azurerm_resource_group.hristoorg.location
  service_plan_id     = azurerm_service_plan.hristoasp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserverhristo.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.hristodatabase.name};User ID=${azurerm_mssql_server.sqlserverhristo.administrator_login};Password=${azurerm_mssql_server.sqlserverhristo.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_mssql_server" "sqlserverhristo" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.hristoorg.name
  location                     = azurerm_resource_group.hristoorg.location
  version                      = "12.0"
  administrator_login          = var.sql_user
  administrator_login_password = var.sql_user_pass
}

resource "azurerm_mssql_database" "hristodatabase" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sqlserverhristo.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  zone_redundant = false
  sku_name       = "S0"
}

resource "azurerm_mssql_firewall_rule" "hristofirewall" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserverhristo.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "github" {
  app_id                 = azurerm_linux_web_app.hristoalwa.id
  repo_url               = var.github_repo
  branch                 = "main"
  use_manual_integration = true
}

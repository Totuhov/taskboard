terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.12.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "1f38b3b6-2bc0-46d4-bd27-6fe501c3b665"
  features {
  }
}

#Generate a random integer for globally unique name

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.ressource_group_name}${random_integer.ri.result}"
  location = var.ressource_group_location
}

resource "azurerm_service_plan" "rp" {
  name                = "${var.service_plan_name}${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "F1"
}


resource "azurerm_linux_web_app" "wa" {
  name                = "${var.linux_web_app_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.rp.location
  service_plan_id     = azurerm_service_plan.rp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "Default Connection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.mssqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};User ID=${azurerm_mssql_server.mssqlserver.administrator_login};Password=${azurerm_mssql_server.mssqlserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_mssql_server" "mssqlserver" {
  name                         = "${var.mssql_server_name}${random_integer.ri.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.database_administrator_username
  administrator_login_password = var.database_administrator_password
}

resource "azurerm_mssql_database" "db" {
  name           = var.database_name
  server_id      = azurerm_mssql_server.mssqlserver.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  zone_redundant = false
  sku_name       = "S0"
}

resource "azurerm_mssql_firewall_rule" "fr" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.mssqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "sc" {
  app_id                 = azurerm_linux_web_app.wa.id
  repo_url               = var.github_repo_url
  branch                 = "main"
  use_manual_integration = false
}

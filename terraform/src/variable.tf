variable "location" {
    type = string
    default = "North Europe"
}

variable "resource_group_name" {
    type = string
    default = "aks-vm-platform-rg"
}

variable "storage_account_prefix" {
    type = string
    default = "aksvmplatformtf"
}

variable "environment" {
    type = string
    default = "nonprod"
}

variable "subscription_id" {
    type = string
    default = "029910ea-8f05-405d-a05d-c5550d1d02c0" # MandS - V2 - Sandbox - Shared Services - CloudService
}
# This file recreates the bash scripts from the kubernetes-the-hard-way repository using PowerShell syntax
# This is from tutorial 1: Prerequisites - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/01-prerequisites.md

# This tutorial leverages the Microsoft Azure to streamline provisioning of the compute infrastructure required to bootstrap a Kubernetes cluster from the ground up. Sign up for $200 in free credits. In Azure Free Trial there is a limit of 4 Cores available, therefore tutorial instructions must be changed to create 4 nodes instead of 6 (2 controllers and 2 workers).

# Estimated cost to run this tutorial: $0.4 per hour ($10 per day).


# Verify that the Azure CLI is installed and configured
# Verify the version is 2.46.0 or higher
az --version

# Create a default resource group in this case the resource group is named "kubernetes" and the location is "eastus"
# You can change the resource group name and location as needed
az group create -n kubernetes -l eastus

# Next Tutorial: Installing the Client Tools - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/02-client-tools.md
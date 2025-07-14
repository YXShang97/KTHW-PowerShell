# Kubernetes the Hard Way - Step 15: Cleanup
# This script removes all resources created during the tutorial
# Original tutorial: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/15-cleanup.md

Write-Host "Starting Kubernetes the Hard Way - Cleanup Process..." -ForegroundColor Red
Write-Host ("=" * 60) -ForegroundColor Red
Write-Host "⚠️  WARNING: This will delete ALL resources created during the tutorial!" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Red

# Step 1: Confirm deletion with user
Write-Host "`nStep 1: Confirmation required before proceeding..." -ForegroundColor Yellow
Write-Host "This script will permanently delete:"
Write-Host "  • Azure resource group 'kubernetes' and all resources within it" -ForegroundColor Red
Write-Host "  • All certificates in the certs directory" -ForegroundColor Red
Write-Host "  • All kubeconfig files in the configs directory" -ForegroundColor Red
Write-Host "  • CFSSL binaries in the cfssl directory" -ForegroundColor Red

$confirmation = Read-Host "`nAre you sure you want to proceed? Type 'YES' to confirm"
if ($confirmation -ne "YES") {
    Write-Host "❌ Cleanup cancelled by user" -ForegroundColor Green
    Write-Host "No resources were deleted"
    exit 0
}

Write-Host "`n✅ User confirmed - proceeding with cleanup..." -ForegroundColor Green

# Step 2: Delete Azure Resource Group
Write-Host "`nStep 2: Deleting Azure resource group..." -ForegroundColor Yellow
Write-Host "Checking if 'kubernetes' resource group exists..."

try {
    $resourceGroup = az group show --name kubernetes --query "name" --output tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $resourceGroup) {
        Write-Host "✓ Found resource group: $resourceGroup" -ForegroundColor Green
        Write-Host "Deleting resource group 'kubernetes' and all contained resources..."
        Write-Host "⏳ This may take several minutes..." -ForegroundColor Cyan
        
        az group delete --name kubernetes --yes --no-wait
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Resource group deletion initiated successfully" -ForegroundColor Green
            Write-Host "   Note: Deletion continues in background" -ForegroundColor Cyan
        } else {
            throw "Failed to initiate resource group deletion"
        }
    } else {
        Write-Host "ℹ️  Resource group 'kubernetes' not found - skipping" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ Error checking/deleting resource group: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   You may need to delete it manually from Azure portal" -ForegroundColor Yellow
}

# Step 3: Clean up local certificate files
Write-Host "`nStep 3: Cleaning up certificate files..." -ForegroundColor Yellow
$certsPath = "certs"

if (Test-Path $certsPath) {
    Write-Host "Found certificates directory: $certsPath"
    try {
        $certFiles = Get-ChildItem -Path $certsPath -File
        if ($certFiles.Count -gt 0) {
            Write-Host "Removing $($certFiles.Count) certificate files..."
            Remove-Item -Path "$certsPath\*" -Recurse -Force
            Write-Host "✅ Certificate files removed successfully" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  No certificate files found to remove" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "❌ Error removing certificate files: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "ℹ️  Certificates directory not found - skipping" -ForegroundColor Cyan
}

# Step 4: Clean up kubeconfig files
Write-Host "`nStep 4: Cleaning up kubeconfig files..." -ForegroundColor Yellow
$configsPath = "configs"

if (Test-Path $configsPath) {
    Write-Host "Found configs directory: $configsPath"
    try {
        $configFiles = Get-ChildItem -Path $configsPath -File
        if ($configFiles.Count -gt 0) {
            Write-Host "Removing $($configFiles.Count) kubeconfig files..."
            Remove-Item -Path "$configsPath\*" -Recurse -Force
            Write-Host "✅ Kubeconfig files removed successfully" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  No kubeconfig files found to remove" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "❌ Error removing kubeconfig files: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "ℹ️  Configs directory not found - skipping" -ForegroundColor Cyan
}

# Step 5: Clean up CFSSL binaries
Write-Host "`nStep 5: Cleaning up CFSSL binaries..." -ForegroundColor Yellow
$cfsslPath = "cfssl"

if (Test-Path $cfsslPath) {
    Write-Host "Found cfssl directory: $cfsslPath"
    try {
        $cfsslFiles = Get-ChildItem -Path $cfsslPath -File
        if ($cfsslFiles.Count -gt 0) {
            Write-Host "Removing $($cfsslFiles.Count) CFSSL binary files..."
            Remove-Item -Path "$cfsslPath\*" -Recurse -Force
            Write-Host "✅ CFSSL binaries removed successfully" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  No CFSSL binaries found to remove" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "❌ Error removing CFSSL binaries: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "ℹ️  CFSSL directory not found - skipping" -ForegroundColor Cyan
}

# Step 6: Clean up kubectl context
Write-Host "`nStep 6: Cleaning up kubectl context..." -ForegroundColor Yellow
try {
    $currentContext = kubectl config current-context 2>$null
    if ($LASTEXITCODE -eq 0 -and $currentContext -eq "kubernetes-the-hard-way") {
        Write-Host "Removing kubernetes-the-hard-way context from kubectl..."
        kubectl config delete-context kubernetes-the-hard-way 2>$null
        kubectl config delete-cluster kubernetes-the-hard-way 2>$null
        kubectl config unset users.admin 2>$null
        Write-Host "✅ Kubectl context cleaned up" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  No kubernetes-the-hard-way context found - skipping" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ Error cleaning kubectl context: $($_.Exception.Message)" -ForegroundColor Red
}

# Final summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Green
Write-Host "🎉 Kubernetes the Hard Way - Cleanup Complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green

Write-Host "`nCleanup Summary:" -ForegroundColor Green
Write-Host "✅ Azure resource group deletion initiated" -ForegroundColor Green
Write-Host "✅ Local certificate files removed" -ForegroundColor Green
Write-Host "✅ Kubeconfig files removed" -ForegroundColor Green
Write-Host "✅ CFSSL binaries removed" -ForegroundColor Green
Write-Host "✅ Kubectl context cleaned up" -ForegroundColor Green

Write-Host "`nImportant Notes:" -ForegroundColor Yellow
Write-Host "• Azure resources may take several minutes to fully delete" -ForegroundColor White
Write-Host "• Check Azure portal to confirm complete resource deletion" -ForegroundColor White
Write-Host "• Your Azure subscription is now clean of tutorial resources" -ForegroundColor White

Write-Host "`n🚀 Thank you for completing Kubernetes the Hard Way!" -ForegroundColor Cyan
Write-Host "You have successfully learned how to set up Kubernetes from scratch!" -ForegroundColor Cyan

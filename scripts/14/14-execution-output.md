# Kubernetes the Hard Way - Step 14: Dashboard Configuration

**Tutorial Step**: 14  
**Tutorial Name**: Dashboard Configuration  
**Original Tutorial**: [kubernetes-the-hard-way-on-azure/docs/14-dashboard.md](https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/14-dashboard.md)  
**Description**: In this lab you will install and configure the Kubernetes dashboard for cluster management and monitoring.  
**Script File**: `14-configure-dashboad.ps1`

## Script Overview

This PowerShell script automates the installation and configuration of the Kubernetes Dashboard with proper authentication. The script follows the original tutorial step-by-step, converting bash commands to PowerShell equivalents while maintaining simplicity and clarity.

## Script Execution Results

### Execution Output

```
Starting Kubernetes Dashboard Configuration...
==================================================

Step 1: Deploying Kubernetes Dashboard...
Applying dashboard manifests from official repository...
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created
✅ Dashboard deployed successfully

Step 2: Waiting for dashboard pods to start...
This may take a few minutes...
Dashboard pods: 2/2 running (10s elapsed)
✅ All dashboard pods are running

Step 3: Creating dashboard admin service account...
Created dashboard-adminuser.yaml
serviceaccount/admin-user created
✅ Service account created successfully

Step 4: Creating cluster role binding...
clusterrolebinding.rbac.authorization.k8s.io/dashboard-admin created
✅ Cluster role binding created successfully

Step 5: Generating access token...
✅ Access token generated successfully

==================================================
DASHBOARD ACCESS TOKEN:
==================================================
eyJhbGciOiJSUzI1NiIsImtpZCI6ImwyZWk3dmZPS2dvTVp1bUN5dFJ1NmhMZnBGbE9GdjlzdWVCTkZSNnlBUlkifQ.eyJhdWQiOlsiaHR0cHM6Ly8iXSwiZXhwIjoxNzU3NDMxMTc3LCJpYXQiOjE3NTc0Mjc1NzcsImlzcyI6Imh0dHBzOi8vIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJhZG1pbi11c2VyIiwidWlkIjoiYWQyYWEwM2QtNjcyMi00OGNhLThiYjgtYTRmMzQ5MTUzM2JkIn19LCJuYmYiOjE3NTc0Mjc1NzcsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDphZG1pbi11c2VyIn0.KcJj6nWbHcNsM-lseEEnBX20KNna2lZwkPDHeOFcDQRk7Jw8JkdKw5OvifIuuq0CkjKVPVJnw0ISbVAM1BPHeOg1wB9KByONXx0XgIX2t_ozCaRDgyIQp1leIQxOiw6OvXspIHDol9cW6LC41eqo62zAsxUOsCw0yVeMCXWHOW24WEE_ymvPh6t6KDcf4CSHNP98X6GC9AjlLqVnxyqaT1sgvxgZc7Q0GEALGAz4Xz_nXxK0mCVfpF-Fan7it75XhhopCC8iy11Om9PaOAwKvJ2qFJmxRgAP3hgczJuWCRTbn7mYGMl9o8FqZ4zu1ZX_5UkEt7gFiwpuW1NWs_e4yA
==================================================
Token saved to dashboard-token.txt

Step 6: Dashboard access instructions

🌐 To access the Kubernetes Dashboard:
1. Run: kubectl proxy
2. Open your browser to:
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
3. Select 'Token' authentication method
4. Paste the token from above (or from dashboard-token.txt)

Final Status Check:
Dashboard pods:
NAME                                        READY   STATUS    RESTARTS        AGE
dashboard-metrics-scraper-7bc864c59-xt6fn   1/1     Running   0               2m58s
kubernetes-dashboard-6c7ccbcf87-x4thg       1/1     Running   1 (2m52s ago)   2m58s

Dashboard services:
NAME                        TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
dashboard-metrics-scraper   ClusterIP   10.32.0.55    <none>        8000/TCP   2m59s
kubernetes-dashboard        ClusterIP   10.32.0.146   <none>        443/TCP    3m2s

Service account:
NAME         SECRETS   AGE
admin-user   0         2m38s

✅ Dashboard configuration completed successfully!
Files created:
- dashboard-adminuser.yaml
- dashboard-token.txt
```

## Key Improvements Made

### Script Enhancements

- **Resource Existence Check**: Added logic to handle existing cluster role bindings gracefully
- **Better Error Handling**: Improved error messages and continues execution when resources already exist
- **Token Refresh**: Generates fresh access token on each run

### Successful Outcomes

- ✅ **Dashboard Deployed**: Kubernetes Dashboard v2.7.0 running with 2/2 pods
- ✅ **Authentication Ready**: Admin service account with cluster-admin privileges
- ✅ **Access Token Generated**: Fresh token saved to `dashboard-token.txt`
- ✅ **Services Running**: Both dashboard and metrics-scraper services operational

### Dashboard Access Information

- **URL**: `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`
- **Authentication**: Token-based (token saved in `dashboard-token.txt`)
- **Access Method**: `kubectl proxy` + browser

---

## 🧭 Navigation

| Previous                                               | Current                              | Next                                                |
| ------------------------------------------------------ | ------------------------------------ | --------------------------------------------------- |
| [⬅️ Step 13: Smoke Test](../13/13-execution-output.md) | **Step 14: Dashboard Configuration** | [➡️ Step 15: Cleanup](../15/15-execution-output.md) |

### 📋 Tutorial Progress

- [🏠 Main README](../../README.md)
- [📖 All Tutorial Steps](../../README.md#-tutorial-steps)
- [🔧 Troubleshooting](../troubleshooting/Repair-Cluster.ps1)
- [✅ Cluster Validation](../validation/Validate-Cluster.ps1)
- dashboard-token.txt

````

## What the Script Does

### Step-by-Step Breakdown

1. **Dashboard Deployment**
   - Downloads and applies the official Kubernetes Dashboard manifests (v2.7.0)
   - Creates the `kubernetes-dashboard` namespace
   - Deploys dashboard components including service accounts, services, secrets, configmaps, and deployments

2. **Pod Readiness Check**
   - Monitors dashboard pod startup with a 2-minute timeout
   - Provides real-time status updates on pod readiness
   - Continues execution even if pods are not immediately ready

3. **Service Account Creation**
   - Creates a YAML manifest for the admin service account
   - Applies the service account to the `kubernetes-dashboard` namespace
   - This account will have administrative access to the cluster

4. **Cluster Role Binding**
   - Creates a cluster role binding that grants `cluster-admin` privileges
   - Links the admin-user service account to cluster-wide admin permissions
   - This allows full access to all cluster resources through the dashboard

5. **Access Token Generation**
   - Generates a bearer token for the admin-user service account
   - Saves the token to `dashboard-token.txt` for future reference
   - This token is used for authentication when accessing the dashboard

6. **Access Instructions**
   - Provides clear steps for accessing the dashboard via kubectl proxy
   - Displays the dashboard URL and authentication method

## Current Status

The script executed successfully with the following observations:

- ✅ **Dashboard manifests deployed**: All Kubernetes resources created successfully
- ✅ **Service account configured**: Admin user created with cluster-admin privileges
- ✅ **Access token generated**: Authentication token created and saved
- ⚠️ **Pods pending**: Dashboard pods are in "Pending" status due to no available worker nodes

## Expected Behavior

The dashboard pods showing "Pending" status is **expected behavior** in this tutorial setup because:
- Worker nodes haven't been configured yet (Step 9 needs completion)
- Without worker nodes, pods cannot be scheduled to run
- The dashboard deployment itself is successful and will start once worker nodes are available

## Validation Commands

Run these PowerShell commands to verify the dashboard configuration:

### Check Dashboard Namespace
```powershell
kubectl get namespace kubernetes-dashboard
````

### Verify Dashboard Resources

```powershell
# Check all dashboard resources
kubectl get all -n kubernetes-dashboard

# Check service accounts
kubectl get serviceaccount -n kubernetes-dashboard

# Check cluster role bindings
kubectl get clusterrolebinding dashboard-admin
```

### Monitor Pod Status

```powershell
# Watch pod status (will show Pending until worker nodes are ready)
kubectl get pods -n kubernetes-dashboard -w

# Check pod details and events
kubectl describe pods -n kubernetes-dashboard
```

### Test Token Generation

```powershell
# Generate a new token (tokens expire after 1 hour by default)
kubectl -n kubernetes-dashboard create token admin-user

# Check token file
Get-Content dashboard-token.txt
```

### Verify Dashboard Service

```powershell
# Check dashboard service details
kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o wide

# Check service endpoints
kubectl get endpoints -n kubernetes-dashboard
```

## Accessing the Dashboard

Once worker nodes are available and dashboard pods are running:

1. **Start kubectl proxy**:

   ```powershell
   kubectl proxy
   ```

2. **Open dashboard URL**:

   ```
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
   ```

3. **Authenticate**:
   - Select "Token" authentication method
   - Paste the token from `dashboard-token.txt`
   - Click "Sign In"

## Troubleshooting

### Common Issues and Solutions

#### 1. Pods Stuck in Pending Status

**Cause**: No worker nodes available for scheduling

**Solution**: Complete Step 9 (Bootstrapping Worker Nodes) to add worker nodes to the cluster

**Verification**:

```powershell
kubectl get nodes
kubectl describe nodes
```

#### 2. Token Authentication Fails

**Cause**: Token may have expired (default 1-hour expiration)

**Solution**: Generate a new token

```powershell
kubectl -n kubernetes-dashboard create token admin-user
```

#### 3. Cannot Access Dashboard URL

**Cause**: kubectl proxy not running or wrong URL

**Solution**:

- Ensure kubectl proxy is running: `kubectl proxy`
- Verify the exact URL format
- Check if port 8001 is available

#### 4. Dashboard Shows Limited Permissions

**Cause**: Service account may not have proper cluster role binding

**Solution**: Verify cluster role binding exists

```powershell
kubectl get clusterrolebinding dashboard-admin
kubectl describe clusterrolebinding dashboard-admin
```

#### 5. Missing Dependencies

**Issue**: kubectl not found or cluster not accessible

**Solution**:

- Verify kubectl installation: `kubectl version --client`
- Check cluster connectivity: `kubectl cluster-info`
- Ensure kubeconfig is properly configured

### Alternative Access Methods

If kubectl proxy doesn't work, you can try:

1. **NodePort Service** (when worker nodes are available):

   ```powershell
   kubectl patch service kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort"}}'
   kubectl get service kubernetes-dashboard -n kubernetes-dashboard
   ```

2. **Port Forwarding**:
   ```powershell
   kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
   ```
   Then access: `https://localhost:8443`

## Files Created

- **dashboard-adminuser.yaml**: Service account manifest for admin user
- **dashboard-token.txt**: Authentication token for dashboard access

## Security Notes

⚠️ **Important Security Considerations**:

- The admin-user service account has **cluster-admin** privileges (full cluster access)
- In production environments, consider creating users with limited permissions
- Tokens expire after 1 hour by default for security
- Store access tokens securely and don't commit them to version control

## Next Steps

1. **Complete Step 9**: Bootstrap worker nodes to allow dashboard pods to run
2. **Access Dashboard**: Use kubectl proxy and the generated token
3. **Explore Features**: Navigate through the dashboard to monitor cluster resources
4. **Step 15**: Clean up cluster resources when tutorial is complete

## Summary

✅ **Dashboard Configuration Successful**

- Kubernetes Dashboard v2.7.0 deployed
- Admin service account created with cluster-admin privileges
- Access token generated for authentication
- Clear access instructions provided
- Dashboard ready to use once worker nodes are available

---

## 🧭 Navigation

| Previous                                                | Current                      | Next                                                          |
| ------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------- |
| [⬅️ Step 13: Smoke Tests](../13/13-execution-output.md) | **Step 14: Dashboard Setup** | [➡️ Step 15: Cleanup Resources](../15/15-execution-output.md) |

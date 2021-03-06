# Download and unpack Istio
ISTIO_VERSION=1.0.4
DOWNLOAD_URL=https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux.tar.gz

wget $DOWNLOAD_URL
tar xzf istio-${ISTIO_VERSION}-linux.tar.gz
cd istio-${ISTIO_VERSION}

# Copy CRDs template
cp install/kubernetes/helm/istio/templates/crds.yaml ../istio-crds.yaml

# A template with sidecar injection enabled.
helm template --namespace=istio-system \
  --set sidecarInjectorWebhook.enabled=true \
  --set sidecarInjectorWebhook.enableNamespacesByDefault=true \
  --set global.proxy.autoInject=disabled \
  --set global.disablePolicyChecks=true \
  --set prometheus.enabled=false \
  `# Disable mixer policy check, since in our template we set no policy.` \
  --set global.disablePolicyChecks=true \
  `# Set a generous number of pilot replicas to avoid Pilot being overloaded.` \
  --set pilot.autoscaleMin=3 \
  --set pilot.autoscaleMax=10 \
  --set pilot.cpu.targetAverageUtilization=60 \
  install/kubernetes/helm/istio > ../istio.yaml

# A liter template, with no sidecar injection.  We could probably remove
# more from this template.
helm template --namespace=istio-system \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set global.disablePolicyChecks=true \
  --set prometheus.enabled=false \
  `# Disable mixer policy check, since in our template we set no policy.` \
  --set global.disablePolicyChecks=true \
  install/kubernetes/helm/istio > ../istio-lean.yaml

# Clean up.
cd ..
rm -rf istio-${ISTIO_VERSION}
rm istio-${ISTIO_VERSION}-linux.tar.gz

# Add in the `istio-system` namespace, so we only need to
# run one kubectl command to install istio.
patch istio.yaml namespace.yaml.patch
patch istio-lean.yaml namespace.yaml.patch

# Add in the prestop sleep to workaround https://github.com/knative/serving/issues/2351.
#
# We need to replace this with some better solution like retries.
patch istio.yaml prestop-sleep.yaml.patch

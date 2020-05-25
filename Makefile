PACKER_CMD ?= packer
RELEASE ?= stable
VERSION ?= current
DIGEST_URL ?= https://$(RELEASE).release.flatcar-linux.net/amd64-usr/current/flatcar_production_iso_image.iso.DIGESTS
CONFIG ?= flatcar-linux-config.yml
DISK_SIZE ?= 40000
MEMORY ?= 2048M
BOOT_WAIT ?= 45s
CT_DOWNLOAD_URL ?= https://github.com/coreos/container-linux-config-transpiler/releases/download
CT_VER ?= v0.9.0
PACKER_VERSION ?= 1.5.6
ARCH ?= $(shell uname -m)
HEADLESS ?= false
ACCELERATION ?= kvm
PUB_FILE=unsec_priv_key_make.pub

flatcar-linux: builds/flatcar-linux-$(RELEASE).qcow2

builds/flatcar-linux-$(RELEASE).qcow2:
	$(eval ISO_CHECKSUM := $(shell curl -s "$(DIGEST_URL)" | grep "flatcar_production_iso_image.iso" | awk '{ print length, $$1 | "sort -rg"}' | awk 'NR == 1 { print $$2 }'))

	ct -pretty -in-file $(CONFIG) -out-file ignition.json

	$(PACKER_CMD) build -force \
		-var 'flatcar_channel=$(RELEASE)' \
		-var 'flatcar_version=$(VERSION)' \
		-var 'iso_checksum=$(ISO_CHECKSUM)' \
		-var 'iso_checksum_type=sha512' \
		-var 'disk_size=$(DISK_SIZE)' \
		-var 'memory=$(MEMORY)' \
		-var 'boot_wait=$(BOOT_WAIT)' \
		-var 'headless=$(HEADLESS)' \
		-var 'acceleration=$(ACCELERATION)' \
		flatcar-linux.json

clean: cache-clean ct-clean
	rm -rf builds unsec_priv_key_make unsec_priv_key_make.pub || true

cache-clean:
	rm -rf packer_cache || true

packer:
ifeq (,$(wildcard /usr/local/bin/packer))
	curl -LO https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
		&& unzip packer_${PACKER_VERSION}_linux_amd64.zip -d /usr/local/bin
endif

ct: /usr/local/bin/ct

/usr/local/bin/ct:
	wget $(CT_DOWNLOAD_URL)/$(CT_VER)/ct-$(CT_VER)-$(ARCH)-unknown-linux-gnu -O /usr/local/bin/ct
	chmod +x /usr/local/bin/ct

ct-update: ct-clean ct

ct-clean:
	rm /usr/local/bin/ct
ssh_init:
ifeq (,$(wildcard unsec_priv_key_make))
	ssh-keygen -f unsec_priv_key_make -N ''
endif
	PUB_KEY=`cat $(PUB_FILE)`

init_all: ssh_init
	echo $(PUB_KEY)
	echo {"ignition":{"config":{},"timeouts":{},"version":"2.1.0"},"networkd":{},"passwd":{"users":[{"name":"core","passwordHash":"$6$W/hBm987$xhFCKIxUAiHPCe39kDyoQ3Dbsyt9UqCGu..GKX8fwv/Aa.kB4i8imua2DP1As4ZurOGcjx4pRXzrILIvGbFro0","sshAuthorizedKeys":["$(PUB_KEY)"]}]},"storage":{},"systemd":{}} > boot.ign

init_all: ssh_init
	echo $(PUB_KEY)

kubespray_init:
	python3 -m venv .venv
	git clone --branch ${KUBESPRAY_VERSION} https://github.com/kubernetes-sigs/kubespray.git
	.venv/bin/pip3 install -r kubespray/requirements.txt

.PHONY: clean cache-clean ct-clean

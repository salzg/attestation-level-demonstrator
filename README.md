# attestation-level-demonstrator
Uses [ALman](https://github.com/salzg/attestation-level-manager) and [SAVS](https://github.com/salzg/simple-attestation-verifier-service) to make small security demonstrator.

## Basic idea

This is a demonstrator to showcase the necessity of AL4 to mitigate the threat of Workload Substitution when using AMD SEV-SNP (and Confidential Computing as a whole). This demonstrator spins up 10 VMs. 4 VMs are running a genuine application at a different AL each. 4 VMs are running a "malicious" application at a different AL each. Finally, 2 VMs are running a genuine application, but one uses a different Guest Firmware and the other has a different kernel cmdline.
![Demonstrator Diagram](./images/AttestationLevelDemonstrator.svg)


## Preparing the host

Set up and follow the instructions in [ALman](https://github.com/salzg/attestation-level-manager). Similarly, set up [SAVS](https://github.com/salzg/simple-attestation-verifier-service). This repo assumes you have aliased `alman` to the ALman `alman.sh` script.

## Building the base images

Build a base-image using the `additional-build.sh` from this repo. Edit the Server IP to match your server's IP and the host port to match the intended SAVS port.

This is going to be the base for the genuine applications:

```bash
vim ~/attesation-level-demonstrator/additional-build.sh
cd ~/attestation-level-manager
sudo alman build-base --additional-cmds-file ~/attestation-level-demonstrator/additional-build.sh \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
```

Now edit `additional-build.sh` by uncommenting the marker on line 11 and build the "evil"/"malicious" base image:

```bash
vim ~/attesation-level-demonstrator/additional-build.sh
sudo alman build-base --additional-cmds-file ~/attestation-level-demonstrator/additional-build.sh \
--base-path ~/attestation-level-manager/cache/evil-base-ubuntu-noble.qcow2
```

Both images should now be located in `~/attestation-level-manager/cache/`.

## Building the malicious VMs

AL1 VM:

```bash
sudo alman build-vm --al 1 --name evil-AL1-vm \
--base-path ~/attestation-level-manager/cache/evil-base-ubuntu-noble.qcow2
```

AL2 VM:

```bash
sudo alman build-vm --al 2 --name evil-AL2-vm \
--base-path ~/attestation-level-manager/cache/evil-base-ubuntu-noble.qcow2
```

AL3 VM:

```bash
sudo alman build-vm --al 3 --name evil-AL3-vm \
--base-path ~/attestation-level-manager/cache/evil-base-ubuntu-noble.qcow2
sudo apply-al --al 3 --name evil-AL3-vm
```

AL4 VM:

```bash
sudo alman build-vm --al 4 --name evil-AL4-vm \
--base-path ~/attestation-level-manager/cache/evil-base-ubuntu-noble.qcow2
sudo apply-al --al 4 --name evil-AL4-vm
ROOTHASH=$(sudo alman make-verity --al 4 --name evil-AL4-vm)
```

## Define the malicious VMs

AL1-4 VMs:

```bash
sudo alman define --al 1 --name evil-AL1-vm
sudo alman define --al 2 --name evil-AL2-vm
sudo alman define --al 3 --name evil-AL1-vm
sudo alman define --al 4 --name evil-AL1-vm
```

## Building the genuine, unmodified VMs

AL1 VM:

```bash
sudo alman build-vm --al 1 --name genuine-AL1-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
```

AL2 VM:

```bash
sudo alman build-vm --al 2 --name genuine-AL2-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
```

AL3 VM:

```bash
sudo alman build-vm --al 3 --name genuine-AL3-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
sudo apply-al --al 3 --name genuine-AL3-vm
```

AL4 VM:

```bash
sudo alman build-vm --al 4 --name genuine-AL4-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
sudo apply-al --al 4 --name genuine-AL4-vm
ROOTHASH=$(sudo alman make-verity --al 4 --name genuine-AL4-vm)
```

## Define the malicious VMs

AL1-4 VMs:

```bash
sudo alman define --al 1 --name genuine-AL1-vm
sudo alman define --al 2 --name genuine-AL2-vm
sudo alman define --al 3 --name genuine-AL3-vm
sudo alman define --al 4 --name genuine-AL4-vm
```

## Building the genuine, modified VMs

To provide a different Guest Firmware, you need different Guest Firmwares. Luckily, you should already have 2 with how you set up ALman. They should be located under `~/ovmf`. Simply edit your `alman.conf` to point to the other firmware. The last two entries should currently look like this:

```
# Optional split firmware paths
OVMF_AL2=/home/ubuntu/ovmf/al12/OVMF.fd
OVMF_AL34=/home/ubuntu/ovmf/al34/OVMF.fd
```

Now edit `OVMF_AL2` to point to the other firmware. It should now look like this:

```
# Optional split firmware paths
OVMF_AL2=/home/ubuntu/ovmf/al34/OVMF.fd
OVMF_AL34=/home/ubuntu/ovmf/al34/OVMF.fd
```

Now VMs up to AL2 will use the AMD-specific OVMF Guest Firmware.

AL2 VM:

```bash
sudo alman build-vm --al 2 --name different-AL2-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
```

AL3 VM:

```bash
sudo alman build-vm --al 3 --name different-AL3-vm \
--base-path ~/attestation-level-manager/cache/genuine-base-ubuntu-noble.qcow2
sudo apply-al --al 3 --name genuine-AL3-vm
```

Revert the lines `alman.conf` to its original state that should look like this:

```
# Optional split firmware paths
OVMF_AL2=/home/ubuntu/ovmf/al12/OVMF.fd
OVMF_AL34=/home/ubuntu/ovmf/al34/OVMF.fd
```

## Define the genuine, modified VMs

```bash
sudo alman define --al 2 --name different-AL2-vm
sudo alman define --al 3 --name different-AL3-vm --cmdline "root=/dev/vda2 rw rootwait console=ttyS0,115200n8 different_cmdline=1"
```

## Start all VMs

```bash
virsh start genuine-AL1-vm
virsh start genuine-AL2-vm
virsh start genuine-AL3-vm
virsh start genuine-AL4-vm
virsh start different-AL2-vm
virsh start different-AL3-vm
virsh start evil-AL1-vm
virsh start evil-AL2-vm
virsh start evil-AL3-vm
virsh start evil-AL4-vm
```

## Set up SAVS server

Get the calculated Reference Values for the "genuine" VMs on AL1 through 4 from the `expected-measurements.json` written by alman and insert them in the following JSON snippet (adjust product name and report version if there is a misalignment with your setup):

```JSON
"al1": {
    "product_name": "Milan",

    "nonce_ttl_seconds": 300,
    "delete_session_after_success": true,

    "allowed_report_versions": [4],
    "expected_measurement_hex": "A5E1C7754D10F9CD6F86262421DBB7C1AB425F91C3F815B05B543506AE062574C5D2176C972AE9383EEC80CDF8D26C30",

    "required_policy_bits_set": "0x30000",
    "forbidden_policy_bits_set": 0,

    "required_flags_bits_set": 0,
    "forbidden_flags_bits_set": 0,
    "min_tcb": { "blSPL": 0, "teeSPL": 0, "snpSPL": 0, "ucodeSPL": 0 },
},
"al2": {
    "product_name": "Milan",

    "nonce_ttl_seconds": 300,
    "delete_session_after_success": true,

    "allowed_report_versions": [4],
    "expected_measurement_hex": "A5E1C7754D10F9CD6F86262421DBB7C1AB425F91C3F815B05B543506AE062574C5D2176C972AE9383EEC80CDF8D26C30",

    "required_policy_bits_set": "0x30000",
    "forbidden_policy_bits_set": 0,

    "required_flags_bits_set": 0,
    "forbidden_flags_bits_set": 0,
    "min_tcb": { "blSPL": 0, "teeSPL": 0, "snpSPL": 0, "ucodeSPL": 0 },
},
"al3": {
    "product_name": "Milan",

    "nonce_ttl_seconds": 300,
    "delete_session_after_success": true,

    "allowed_report_versions": [4],
    "expected_measurement_hex": "A5E1C7754D10F9CD6F86262421DBB7C1AB425F91C3F815B05B543506AE062574C5D2176C972AE9383EEC80CDF8D26C30",

    "required_policy_bits_set": "0x30000",
    "forbidden_policy_bits_set": 0,

    "required_flags_bits_set": 0,
    "forbidden_flags_bits_set": 0,
    "min_tcb": { "blSPL": 0, "teeSPL": 0, "snpSPL": 0, "ucodeSPL": 0 },
},
"al4": {
    "product_name": "Milan",

    "nonce_ttl_seconds": 300,
    "delete_session_after_success": true,

    "allowed_report_versions": [4],
    "expected_measurement_hex": "A5E1C7754D10F9CD6F86262421DBB7C1AB425F91C3F815B05B543506AE062574C5D2176C972AE9383EEC80CDF8D26C30",

    "required_policy_bits_set": "0x30000",
    "forbidden_policy_bits_set": 0,

    "required_flags_bits_set": 0,
    "forbidden_flags_bits_set": 0,
    "min_tcb": { "blSPL": 0, "teeSPL": 0, "snpSPL": 0, "ucodeSPL": 0 },
}
```

Add the JSON snippet to the SAVS Server's `policies.json`.

You can now configure secret on your own or use the suggestion below

```JSON
{ "deployment_name": "al1", "secret": "super-secret-value-al1" },
{ "deployment_name": "al2", "secret": "super-secret-value-al1" },
{ "deployment_name": "al3", "secret": "super-secret-value-al1" },
{ "deployment_name": "al4", "secret": "super-secret-value-al1" },
```

Add your secrets to SAVS Server's `secrets.json`.

And run the Server. Adjust the port if you are using another.

```bash
python3 server/server.py \
    --host 0.0.0.0 \
    --port 8443 \
    --tls-cert ./server.crt \
    --tls-key ./server.key \
    --policies ./server/policies.json \
    --secrets ./server/secrets.json \
    --cache-dir ./server/cache \
    --log-dir ./server/logs
```

## Setting up the Clients

The following part should probably be automated via a cronjob triggered on VM start, but it is manual for now.

Connect to each VM (via ssh or virsh console (don't forget to login via default ubuntu:ubuntu)) and set up the client. Example for genuine-AL1-vm:

```bash
virsh console genuine-AL1-vm
cd /opt/simple-attestation-verifier-service/client
./adjust-config.sh
sudo openssl req -new -newkey rsa:4096 -x509 -days 365 -nodes -out frontend.crt \
-keyout frontend.key -subj "/"
sudo python3 client/client-frontend.py \
    --tls-cert ./frontend.crt \
    --tls-key ./frontend.key \
    --client-config ./client/client_config.json \
    --host 0.0.0.0 \
    --port 9443
```

## Enable port forwarding on the host

Currently, the webfrontend are only accessible from the host itself. You can expose them to the host's network through portforwarding. First, find out the guest VMs IP. `virsh net-dhcp-leases default` should be enough, but sometimes you might need to `virsh console` into the VMs to bugfix. There probably is a way to automatise this, but it's manual for now. The host ports are arbitrarily chosen to be:

* 40001: genuine-AL1-vm
* 40002: genuine-AL2-vm
* 40003: genuine-AL3-vm
* 40004: genuine-AL4-vm
* 45002: different-AL2-vm
* 45003: different-AL3-vm
* 50001: evil-AL1-vm
* 50002: evil-AL2-vm
* 50003: evil-AL3-vm
* 50004: evil-AL4-vm

Enable port forwarding:

```bash
sudo iptables -A INPUT -p tcp --dport 9443 -j ACCEPT
```

Allow the ports on the hosts. Edit these variables and invoke the scommands below for each VM

```bash
GUEST_PORT=9443
HOST_PORT=50003
GUEST_IP=<GUESTIP>
HOST_IP=<HOSTIP>
```

```bash
sudo iptables -t nat -A PREROUTING \
  -d ${HOST_IP} -p tcp --dport ${HOST_PORT} \
  -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}"

sudo iptables -t nat -A OUTPUT \
  -d ${HOST_IP} -p tcp --dport ${HOST_PORT} \
  -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}"

sudo iptables -I FORWARD 1 \
  -i ens10f0 -o virbr0 -p tcp \
  -d "${GUEST_IP}" --dport "${GUEST_PORT}" \
  -m state --state NEW,ESTABLISHED,RELATED \
  -j ACCEPT

sudo iptables -I FORWARD 1 \
  -i virbr0 -o ens10f0 -p tcp \
  -s "${GUEST_IP}" --sport "${GUEST_PORT}" \
  -m state --state ESTABLISHED,RELATED \
  -j ACCEPT
```

Your VMs should now be reachable via the host network. You can now use the demonstrator to show the issue with not achieving AL4 live.

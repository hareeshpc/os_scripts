# Scripts for Openstack

Automatic scripts to quickly verify the L2 and L3 functionality of a deployed openstack cloud. Useful in sanity runs or create simple test scenarios involving L3.
Diagnostics involve full ping tests with reattempts on set of networks via floating ips.

The floating ip end points can be either a DHCP client (for quick and lightweight tests) as well deploying a full VM.

Reuses existing external networks as part of the test run.


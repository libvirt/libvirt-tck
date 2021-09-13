libvirt TCK  : Technology Compatability Kit
===========================================

The libvirt TCK provides a framework for performing testing
of the integration between libvirt drivers, the underlying virt
hypervisor technology, related operating system services and system
configuration. The idea (and name) is motivated by the Java TCK

In particular the libvirt TCK is intended to address the following
scenarios

- Validate that a new libvirt driver is in compliance
  with the (possibly undocumented!) driver API semantics

- Validate that an update to an existing driver does not
  change the API semantics in a non-compliant manner

- Validate that a new hypervisor release is still providing
  compatability with the corresponding libvirt driver usage

- Validate that an OS distro deployment consisting of a
  hypervisor and libvirt release is configured correctly

Thus the libvirt TCK will allow developers, administrators and users
to determine the level of compatability of their platform, and
evaluate whether it will meet their needs, and get awareness of any
regressions that may have occurred since a previous test run

In relation to other libvirt testing, the split of responsibiity
will be

libvirt testsuite (aka $CHECKOUT/tests)
---------------------------------------

- unit testing of specific internal APIs
- functional testing of the libvirtd using the 'test' driver
- functional testing of the virsh command using the 'test' driver

libvirt TCK
-----------

- functional/integration testing of the 'live' drivers

Running with Avocado
--------------------

In order to run those tests with the Avocado framework, you can execute:

``$ avocado --config avocado.config run ./scripts/domain/*.t``

If you would like to see results in tap, run:

``$ avocado --config avocado.config run --tap - ./scripts/domain/*.t``

Debugging errors
~~~~~~~~~~~~~~~~

Visit ``~avocado/job-results/latest/`` folder to see details and debug files.

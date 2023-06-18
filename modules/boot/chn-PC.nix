{ pkgs, ... }@inputs:
{
	config =
	{
		boot =
		{
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
			
			# initrd 里有的模块
			initrd.availableKernelModules =
			[
				"ahci" "i915" "intel_cstate" "nls_cp437" "nls_iso8859-1" "nvidia" "nvidia_drm" "nvidia_modeset"
				"nvidia_uvm" "nvme" "sr_mod" "usbhid" "usb_storage" "virtio_blk" "virtio_pci" "xhci_pci"
			];

			# stage2 中自动加载的模块
			kernelModules = [ "kvm-intel" "br_netfilter" ];

			# 只安装，不需要自动加载的模块
			# extraModulePackages = [ yourmodulename ];

			extraModprobeConfig =
			''
				options kvm_intel nested=1
				options iwlmvm power_scheme=1
				options iwlwifi uapsd_disable=1
			'';
			kernelParams = [ "delayacct" "acpi_osi=Linux" "resume_offset=19145984" ];
			resumeDevice = "/dev/mapper/root";
		};
		hardware.cpu.intel.updateMicrocode = true;
	};
}

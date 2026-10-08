# Fallbacks
defenv
env default -a
saveenv

setenv bootfromnand 0
setenv ce_on_emmc "no"
setenv sddtb 'if fatload mmc 0 ${dtb_mem_addr} dtb.img; then else store dtb read $dtb_mem_addr; fi'
setenv usbdtb 'if fatload usb 0 ${dtb_mem_addr} dtb.img; then else store dtb read $dtb_mem_addr; fi'
setenv cfgloadsd 'if fatload mmc 0:1 ${loadaddr} cfgload; then setenv device mmc; setenv devnr 0; setenv partnr 1; autoscr ${loadaddr}; fi'
setenv cfgloadusb 'if fatload usb 0:1 ${loadaddr} cfgload; then setenv device usb; setenv devnr 0; setenv partnr 1; autoscr ${loadaddr}; fi'
setenv cfgloademmc 'for p in 1 2 3 4 5 6 7 8 9 A B C D E F 10 11 12 13 14 15 16 17 18; do if fatload mmc 1:${p} ${loadaddr} cfgload; then setenv device mmc; setenv devnr 1; setenv partnr ${p}; setenv ce_on_emmc "yes"; autoscr ${loadaddr}; fi; done;'
setenv bootfromsd 'if mmcinfo; then run cfgloadsd; if fatload mmc 0 ${loadaddr} kernel.img; then run sddtb; setenv bootargs ${bootargs} bootfromsd; bootm; fi; fi'
setenv bootfromusb 'usb start 0; run cfgloadusb; if fatload usb 0 ${loadaddr} kernel.img; then run usbdtb; setenv bootargs ${bootargs} bootfromusb; bootm; fi'
setenv bootfromemmc 'run cfgloademmc'

setenv start_autoscript 'if mmcinfo; then run start_mmc_autoscript; fi; if usb start; then run start_usb_autoscript; fi; run start_emmc_autoscript'

setenv start_emmc_autoscript 'if fatload mmc 1 1020000 emmc_autoscript; then setenv devtype "mmc"; setenv devnum 1; autoscr 1020000; fi;'

setenv start_mmc_autoscript 'if fatload mmc 0 1020000 s905_autoscript; then setenv devtype "mmc"; setenv devnum 0; autoscr 1020000; fi;'

setenv start_usb_autoscript 'for usbdev in 0 1 2 3; do if fatload usb ${usbdev} 1020000 s905_autoscript; then setenv devtype "usb"; setenv devnum ${usbdev}; autoscr 1020000; fi; done'

setenv bootcmd 'if test ${bootfromnand} = 1; then setenv bootfromnand 0; saveenv; else run bootfromsd; run bootfromusb; run bootfromemmc; fi; run start_autoscript'
setenv bootdelay 1

setenv cvbsmode 480cvbs
setenv cvbs_drv 0

setenv bootlogo_filename 'bootlogo'
setenv logo_usb_init 'usb start'
setenv logo_try_usb 'for usbdev in 0 1 2 3; do if test ${logo_ok} = 0; then if fatload usb ${usbdev} $loadaddr ${bootlogo_filename}.bmp; then setenv logo_ok 1; fi; fi; done'
setenv logo_try_sd 'mmcinfo; fatload mmc 0:1 $loadaddr ${bootlogo_filename}.bmp && setenv logo_ok 1'
setenv logo_try_emmc 'fatload mmc 1:1 $loadaddr ${bootlogo_filename}.bmp && setenv logo_ok 1'

setenv cvbs_boot 1

setenv select_outputmode 'if hdmitx hpd; then setenv hdmi_cable 0; else setenv hdmi_cable 1; fi; if hdmitx get_preferred_mode; then echo EDID preferred mode read OK; else if test "${hdmi_cable}" = "0"; then echo INFO: hdmitx get_preferred_mode skipped, no HDMI cable connected; else echo WARNING: hdmitx get_preferred_mode error or not available on this firmware; fi; fi; if hdmitx get_parse_edid; then echo EDID parse OK; else if test "${hdmi_cable}" = "0"; then echo INFO: hdmitx get_parse_edid skipped, no HDMI cable connected; else echo WARNING: hdmitx get_parse_edid error or not available on this firmware; fi; fi; if test "${outputmode}" = ""; then setenv outputmode 1080p60hz; else if test "${outputmode}" = "${cvbsmode}"; then test "${cvbs_boot}" = "1" || setenv outputmode ${hdmimode}; fi; fi'

setenv apply_outputmode 'if test "${outputmode}" = "${hdmimode}"; then hdmitx output ${outputmode}; fi; vout output ${outputmode}'

setenv logo_show 'test ${logo_ok} = 1 && osd open && osd clear && bmp display $loadaddr && bmp scale'

##################################################################################################################################
#### Escolha somente UMA opcao de init_display (deixe uma descomentada e as demais comentadas).
#### Todas as opcoes ainda executam osd open e osd clear antes de exibir o bootlogo (dentro do logo_show).
#### A diferenca esta em abrir/limpar o OSD tambem antes e/ou depois do vout, o que pode mudar a cor de fundo mostrada
#### enquanto o logo e procurado (por exemplo, tela azul ou verde, dependendo da TV Box).
#### Se uma opcao nao melhorar o resultado na sua TV Box, volte para a Option A.

#### Choose only ONE init_display option (leave one uncommented and the others commented out).
#### All options still run osd open and osd clear before displaying the bootlogo (inside logo_show).
#### The difference is whether the OSD is also opened/cleared before and/or after vout, which may change the background color
#### shown while the logo is being searched for (for example, a blue or green screen, depending on the TV Box).
#### If an option does not improve the result on your TV Box, go back to Option A.

#### Option A (padrao / default): OSD somente no logo_show / OSD only in logo_show

setenv init_display 'run select_outputmode; run apply_outputmode; setenv logo_ok 0; run logo_usb_init; run logo_try_usb; test ${logo_ok} = 1 || run logo_try_sd; test ${logo_ok} = 1 || run logo_try_emmc; run logo_show'

#### Option B: OSD aberto/limpo ANTES do vout / OSD opened/cleared BEFORE vout

#setenv init_display 'osd open; osd clear; run select_outputmode; run apply_outputmode; setenv logo_ok 0; run logo_usb_init; run logo_try_usb; test ${logo_ok} = 1 || run logo_try_sd; test ${logo_ok} = 1 || run logo_try_emmc; run logo_show'

#### Option C: OSD aberto/limpo DEPOIS do vout / OSD opened/cleared AFTER vout

#setenv init_display 'run select_outputmode; run apply_outputmode; osd open; osd clear; setenv logo_ok 0; run logo_usb_init; run logo_try_usb; test ${logo_ok} = 1 || run logo_try_sd; test ${logo_ok} = 1 || run logo_try_emmc; run logo_show'

#### Option D: OSD aberto/limpo ANTES e DEPOIS do vout / OSD opened/cleared BEFORE and AFTER vout

#setenv init_display 'osd open; osd clear; run select_outputmode; run apply_outputmode; osd open; osd clear; setenv logo_ok 0; run logo_usb_init; run logo_try_usb; test ${logo_ok} = 1 || run logo_try_sd; test ${logo_ok} = 1 || run logo_try_emmc; run logo_show'

##################################################################################################################################

setenv preboot 'run init_display'

##################################################################################################################################

#### Se quiser manter a funcionalidade de usar um aml_autoscript, descomente as linhas abaixo  e comente a linha que tem somente setenv update
#### If you want to keep the ability to use an aml_autoscript, uncomment the lines below and comment out the line that only has setenv update

#setenv check_update_button ${upgrade_key}
#setenv update 'run load_aml_autoscript'
#setenv load_aml_autoscript 'if mmcinfo; then if fatload mmc 0 1020000 aml_autoscript; then autoscr 1020000; fi; fi; if usb start; then for usbdev in 0 1 2 3; do if fatload usb ${usbdev} 1020000 aml_autoscript; then autoscr 1020000; fi; done; fi'
#setenv bootcmd 'run check_update_button; if test ${bootfromnand} = 1; then setenv bootfromnand 0; saveenv; else run bootfromsd; run bootfromusb; run bootfromemmc; fi; run start_autoscript'

##################################################################################################################################

setenv update

##################################################################################################################################

setenv EnableSelinux
setenv initargs
setenv storeargs
setenv cmdline_keys
setenv factory_reset_poweroff_protect
setenv wipe_cache
setenv wipe_data
setenv recovery_from_flash
setenv recovery_offset
setenv recovery_part
setenv upgrade_check
setenv upgrade_key
setenv upgrade_sadckey
setenv upgrade_step
setenv sdc_burning
setenv sdcburncfg
setenv usb_burning
setenv try_auto_burn
setenv jtag
setenv firstboot
setenv ipaddr
setenv gatewayip
setenv netmask
setenv serverip
setenv hostname
setenv ethaddr
setenv ip
setenv ethact
setenv storeboot
setenv switch_bootmode
setenv recovery_from_sdcard
setenv recovery_from_udisk
setenv recovery_from_fat_dev
setenv check_udisk_update
setenv storage_param
setenv detect_stbsn
setenv check_result
setenv Irq_check_en
setenv bcb_cmd
setenv common_dtb_load
setenv get_os_type
setenv load_bmp_logo
setenv fs_typef
setenv fatload_dev
setenv dv_fw_addr
setenv dv_fw_dir
setenv dv_fw_dir_odm_ext
setenv dv_fw_dir_vendor
setenv stbsn
setenv vendor_boot_part
setenv colorattribute
setenv dolby_status
setenv dolby_vision_on
setenv hdr_policy
setenv frac_rate_policy
setenv osd_reverse
setenv video_reverse
setenv panel_type
setenv board_logo_part
setenv os_ident_addr
setenv lock
setenv loglevel
setenv fs_type
setenv active_slot
setenv boot_part
setenv loadaddr_rtos
setenv otg_device
setenv silent
setenv auto_upgrade
setenv board_defined_bootup
setenv irremote_update
setenv reboot_mode
setenv reboot_mode_android
setenv update_sdcard
setenv update_udisk
setenv Model
setenv arch
setenv board
setenv board_name
setenv cpu
setenv soc
setenv vendor
setenv loadaddr_kernel

saveenv

run bootfromsd
run bootfromusb
run bootfromemmc
run start_autoscript

# Recompile with:
# mkimage -C none -A arm -T script -d aml_autoscript.command aml_autoscript

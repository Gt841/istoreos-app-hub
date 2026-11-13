#!/bin/sh
case "${1:-}" in
 status)
  if pidof changeguard_bin >/dev/null; then running=true; else running=false; fi
  href=""; [ ! -x /usr/sbin/kaiplus_bin ] || href=/cgi-bin/luci/admin/services/kaiplus
  printf '{"app":"optimemachine","docker":false,"deployed":true,"running":%s,"href":"%s"}\n' "$running" "$href"
 ;;
 start) /etc/init.d/changeguard enable && /etc/init.d/changeguard start ;;
 stop) /etc/init.d/changeguard stop ;;
 *) exit 1 ;;
esac

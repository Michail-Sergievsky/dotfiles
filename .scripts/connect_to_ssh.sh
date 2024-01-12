#!/bin/bash
echo `clear`
plat=""
pref=""
usl=""
echo "Platforms"
echo "1 - lab"
echo "2 - test"
echo "3 - prod"
echo "4 - no_pref"
read input;
case $input in
  1) plat="lab";;
  2) plat="test";;
  3) plat="prod";;
  4) plat="no_pref";;
  *) echo "Error";; 
esac

case $plat in
    lab) pref="_lab";;
    test) pref="_test";;
    prod) pref="_prod";;
    no_pref) pref="";;
esac

echo "uslugi"
echo "1 - megafon-sdp-core"
echo "2 - megafon-sdp-cloud"
echo "3 - rtkin"
echo "4 - megalabs"
echo "5 - freephone"
echo "6 - mats"
echo "7 - mas"
echo "8 - mvpn"
echo "9 - adn"
echo "0 - multifon"
echo "m - media-tel"
echo "v - viva"

read uslug;
case $uslug in
    1) usl="megafon-sdp-core"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    2) usl="megafon-sdp-cloud"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    3) usl="rtkin"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    4) usl="megalabs"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    5) usl="freephone"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    6) usl="mats"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    7) usl="mas"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    8) usl="mvpn"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    9) usl="adn"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    0) usl="multifon"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    m) usl="media-tel"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    v) usl="viva"; awk '/'"$usl"''"$pref"'/{s=NR;p=1;next}/#/{p=0}p&&NR>s' /etc/hosts;;
    *) echo "Error";;
esac

# What a Hetzner project costs a month, in euros with VAT, from the API's
# answers: $servers, $primary_ips, $floating_ips, $volumes, $load_balancers,
# $images and $pricing, each the body of its GET. $day and $days are today's
# day of the month and the month's length, to project traffic to the month's
# end. Prints one line per thing that costs money, then the total.
def gross: (.gross | tonumber);
def at($loc): map(select(.location == $loc))[0];
def place: (.location.name // .datacenter.location.name);
def tib: 1099511627776;
($pricing[0].pricing) as $p
| [
    ($servers[0].servers[] | . as $s
      | ($s.server_type.prices | at($s | place)) as $price
      | ($price.price_monthly | gross) as $monthly
      | (($s.outgoing_traffic // 0) * $days / $day) as $out
      | ([0, ($out - ($s.included_traffic // 0))] | max) as $over
      | {what: "server \($s.name) (\($s.server_type.name))", eur: $monthly},
        (if $s.backup_window != null
         then {what: "backups of \($s.name)",
               eur: ($monthly * ($p.server_backup.percentage | tonumber) / 100)}
         else empty end),
        (if $over > 0
         then {what: "traffic of \($s.name) past what it includes",
               eur: ($over / tib * ($price.price_per_tb_traffic | gross))}
         else empty end)),
    ($primary_ips[0].primary_ips[] | . as $ip
      | ($p.primary_ips | map(select(.type == $ip.type))[0]) as $kind
      | ((($kind.prices // []) | at($ip | place)).price_monthly // {gross: "0"}) as $m
      | {what: "primary \($ip.type) \($ip.name)", eur: ($m | gross)}),
    ($floating_ips[0].floating_ips[] | . as $ip
      | ($p.floating_ips | map(select(.type == $ip.type))[0]) as $kind
      | {what: "floating \($ip.type) \($ip.name)",
         eur: (($kind.prices | at($ip.home_location.name)).price_monthly | gross)}),
    ($volumes[0].volumes[]
      | {what: "volume \(.name) (\(.size) GB)",
         eur: (.size * ($p.volume.price_per_gb_month | gross))}),
    ($load_balancers[0].load_balancers[] | . as $lb
      | {what: "load balancer \($lb.name)",
         eur: (($lb.load_balancer_type.prices | at($lb.location.name)).price_monthly | gross)}),
    ($images[0].images[]
      | {what: "\(.type) \(.description // .id) (\(.image_size // 0) GB)",
         eur: ((.image_size // 0) * ($p.image.price_per_gb_month | gross))})
  ]
| (map("\(.eur * 100 | round / 100)\t\(.what)") | .[]),
  "\(map(.eur) | add // 0 | . * 100 | round / 100)\ttotal"

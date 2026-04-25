<?php
$hash = '$2a$11$SK./ZA9fON3hseSttJcqAOy6s39l/uydHRFz.wmQ1fsRg2iKV5KZ.';
$candidates = [
  'admin123','student123','password123','123456','12345678','campuseatzz',
  'CampusEatzz@123','rudra123','Rudra@123','202307100110025','utu123',
  'utu@123','welcome123','test123','college123','campus123','password'
];
foreach ($candidates as $p) {
  if (password_verify($p, $hash)) {
    echo 'MATCH=' . $p . PHP_EOL;
    exit(0);
  }
}
echo 'NO_MATCH' . PHP_EOL;
?>

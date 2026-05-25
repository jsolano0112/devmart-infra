# Migracion de estado: nombres antiguos -> nuevos (sin recrear EC2)

moved {
  from = tls_private_key.devmart_key
  to   = tls_private_key.devmart
}

moved {
  from = aws_key_pair.devmart_key_pair
  to   = aws_key_pair.devmart
}

moved {
  from = aws_security_group.devmart_sg
  to   = aws_security_group.devmart
}

moved {
  from = aws_eip.devmart_ip
  to   = aws_eip.devmart
}

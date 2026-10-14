-- =====================================================================
-- Auditoria VIDI — redefinir senhas (supervisoras / coordenadores)
-- Rodar no Supabase: SQL Editor → New query → colar tudo → Run
--
-- Não precisa de service_role key nem de script no navegador.
-- Também corrige usuários criados via SQL direto em auth.users, que
-- costumam ficar com colunas de token NULL e sem linha em auth.identities
-- (por isso não aparecem na API e o login falha).
-- =====================================================================

-- 0) Diagnóstico (opcional): quem está afetado
SELECT u.id, u.email, u.email_confirmed_at IS NOT NULL AS confirmado,
       (u.confirmation_token IS NULL OR u.recovery_token IS NULL) AS token_null,
       NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id) AS sem_identity
FROM auth.users u
WHERE u.email LIKE '%@franquiasboticario.com'
   OR u.email LIKE '%@franquiasqdb.com'
   OR u.email LIKE '%@sferamultifranquias.com'
ORDER BY u.email;

-- 1) Colunas de token NULL quebram o login do GoTrue → troca por ''
UPDATE auth.users SET
  confirmation_token         = COALESCE(confirmation_token, ''),
  recovery_token             = COALESCE(recovery_token, ''),
  email_change_token_new     = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  email_change               = COALESCE(email_change, ''),
  phone_change               = COALESCE(phone_change, ''),
  phone_change_token         = COALESCE(phone_change_token, ''),
  reauthentication_token     = COALESCE(reauthentication_token, '')
WHERE email LIKE '%@franquiasboticario.com'
   OR email LIKE '%@franquiasqdb.com'
   OR email LIKE '%@sferamultifranquias.com';

-- 2) Cria a identidade "email" que falta para quem foi inserido via SQL
INSERT INTO auth.identities (id, user_id, provider_id, provider, identity_data,
                             last_sign_in_at, created_at, updated_at)
SELECT gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email,
                          'email_verified', true, 'phone_verified', false),
       now(), now(), now()
FROM auth.users u
WHERE (u.email LIKE '%@franquiasboticario.com'
    OR u.email LIKE '%@franquiasqdb.com'
    OR u.email LIKE '%@sferamultifranquias.com')
  AND NOT EXISTS (SELECT 1 FROM auth.identities i
                  WHERE i.user_id = u.id AND i.provider = 'email');

-- 3) Define a senha provisória (TROQUE 'Vidi@2026' se quiser outra)
--    e confirma o email para não travar no login.
UPDATE auth.users SET
  encrypted_password = extensions.crypt('Vidi@2026', extensions.gen_salt('bf')),
  email_confirmed_at = COALESCE(email_confirmed_at, now()),
  updated_at         = now()
WHERE email LIKE '%@franquiasboticario.com'
   OR email LIKE '%@franquiasqdb.com'
   OR email LIKE '%@sferamultifranquias.com';

-- 4) O app só pede "Sua senha" (e não "Criar senha") se senha_criada = true
UPDATE public.supervisoras SET senha_criada = true
WHERE lower(email) IN (SELECT lower(email) FROM auth.users);
UPDATE public.profiles SET senha_criada = true
WHERE lower(email) IN (SELECT lower(email) FROM auth.users);

-- ---------------------------------------------------------------------
-- Redefinir a senha de UMA pessoa (rodar só este bloco, trocando os valores):
--
-- UPDATE auth.users
--   SET encrypted_password = extensions.crypt('NovaSenha123', extensions.gen_salt('bf')),
--       updated_at = now()
-- WHERE email = 'fulana@franquiasboticario.com';
-- ---------------------------------------------------------------------

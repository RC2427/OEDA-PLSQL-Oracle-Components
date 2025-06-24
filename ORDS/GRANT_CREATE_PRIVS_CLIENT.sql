
DECLARE
  l_roles    owa.vc_arr;
  l_patterns owa.vc_arr;
BEGIN
  --
  ords.create_role(p_role_name => 'oeda.api.access.role');
  --
 ords_metadata.OAUTH.create_client(p_name => 'OEDA Spring Boot Application',
                                    p_grant_type => 'client_credentials',
                                    p_owner => 'APPS',
                                    p_description => 'Client credentials for the OEDA backend',
                                    p_origins_allowed => '',
                                    p_redirect_uri => NULL,
                                    p_support_email => 'admin@oeda.local',
                                    p_support_uri => 'http://oeda.local',
                                    p_privilege_names => '');
  --
  ords_metadata.oauth.grant_client_role(p_client_name => 'OEDA Spring Boot Application',
                                        p_role_name   => 'oeda.api.access.role');
  --
  l_roles(1) := 'oeda.api.access.role';
  l_patterns(1) := '/oeda/download';
  --
  ords.define_privilege(p_privilege_name => 'oeda.download.privilege',
                        p_roles          => l_roles,
                        p_patterns       => l_patterns,
                        p_label          => 'OEDA Download API Privilege',
                        p_description    => 'Grants access to the OEDA artifact download endpoint');
  --
  COMMIT;
END;
/

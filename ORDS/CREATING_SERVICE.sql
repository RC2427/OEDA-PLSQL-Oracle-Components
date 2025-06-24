-- Create the OEDA REST Service
BEGIN

  -- Defining the Module (a logical container for our APIs)
  ords.define_module(p_module_name    => 'oeda.api',
                     p_base_path      => '/oeda/',
                     p_items_per_page => 25,
                     p_status         => 'PUBLISHED',
                     p_comments       => 'OEDA Download Services');

  -- Defining the URL Template for the download operation
  ords.define_template(p_module_name => 'oeda.api',
                       p_pattern     => 'download');

  -- Defining the POST Handler that executes your PL/SQL package
  ords.define_handler(p_module_name => 'oeda.api',
                      p_pattern     => 'download',
                      p_method      => 'POST',
                      p_source_type => ords.source_type_plsql,
                      p_source      => 'DECLARE
										  l_file_content  BLOB;
										  l_status        VARCHAR2(100);
										  l_error_message VARCHAR2(4000);
										BEGIN
										  --
										  apps.xx_oeda_download_utitliy.get_ebs_artifact(p_component_type => :p_component_type,
																						 p_file_name      => :p_file_name,
																						 p_script         => :p_script,
																						 x_file_content   => l_file_content,
																						 x_status         => l_status,
																						 x_error_message  => l_error_message);
										  --
										  IF l_status = ''SUCCESS'' AND l_file_content IS NOT NULL THEN
											--
											:http_status_code := 200;
											owa_util.mime_header(''application/octet-stream'', FALSE);
											htp.p(''Content-Length: '' || dbms_lob.getlength(l_file_content));
											htp.p(''Content-Disposition: attachment; filename="'' || :p_file_name || ''"'');
											owa_util.http_header_close;
											--
											wpg_docload.download_file(l_file_content);
											--
										  ELSE
											:http_status_code := 400;
											:status           := l_status;
											:message          := l_error_message;
										  END IF;
										END;');

  ords.define_parameter(p_module_name        => 'oeda.api',
                        p_pattern            => 'download',
                        p_method             => 'POST',
                        p_name               => 'http_status_code',
                        p_bind_variable_name => 'http_status_code',
                        p_param_type         => 'INT',
                        p_access_method      => 'OUT');

  ords.define_parameter(p_module_name        => 'oeda.api',
                        p_pattern            => 'download',
                        p_method             => 'POST',
                        p_name               => 'status', 
                        p_bind_variable_name => 'status', 
                        p_param_type         => 'STRING',
                        p_access_method      => 'OUT');

  ords.define_parameter(p_module_name        => 'oeda.api',
                        p_pattern            => 'download',
                        p_method             => 'POST',
                        p_name               => 'message', 
                        p_bind_variable_name => 'message', 
                        p_param_type         => 'STRING',
                        p_access_method      => 'OUT');

  COMMIT;
END;
/

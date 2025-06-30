CREATE OR REPLACE PACKAGE BODY XX_OEDA_DOWNLOAD_UTILITY AS
  /*-------------------------------------------------------------------------------------------
  *********************************************************************************************
  Details : Package Body
  
  Package Name : XX_OEDA_DOWNLOAD_UTILITY.pkb
  Description  : OEDA PL/SQL Package for OEDA
  Doc ID       : 
  
  =============================================================================================
  REM    Version     Revision Date           Developer             Change Description 
  ---    -------     ------------            ---------------       ------------------
  REM    1.0         03-JUNE-2025            Rohit Chaudhari       Initial Version
  *********************************************************************************************
  ---------------------------------------------------------------------------------------------*/
  --
  PROCEDURE log(p_msg IN VARCHAR2) IS
  BEGIN
    --
    dbms_output.put_line(p_msg);
    --
  END log;
  --
  PROCEDURE get_checklist(p_seeded_vs        IN VARCHAR2,
                          x_status           OUT VARCHAR2,
                          x_return_checklist OUT SYS.odcivarchar2list) IS
    --
    lc_checklist sys.odcivarchar2list := SYS.odcivarchar2list();
    --
    CURSOR checklist IS
    --
      SELECT ffnh.child_flex_value_low || '=' || ffnh.child_flex_value_high AS pair
      FROM apps.fnd_flex_value_sets           ffvs,
           apps.fnd_flex_values               ffv,
           apps.fnd_flex_values_tl            ffvt,
           apps.fnd_flex_value_norm_hierarchy ffnh
      WHERE 1 = 1
      AND ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND ffnh.flex_value_set_id = ffv.flex_value_set_id
      AND ffv.flex_value_id = ffvt.flex_value_id
      AND ffv.enabled_flag = 'Y'
      AND (ffv.end_date_active IS NULL OR
            trunc(ffv.start_date_active) <= trunc(SYSDATE))
      AND (ffv.end_date_active IS NULL OR
            trunc(ffv.end_date_active) >= trunc(SYSDATE))
      AND ffvt.language = userenv('LANG')
      AND ffvs.flex_value_set_name = p_seeded_vs;
      --
  BEGIN
    --
    FOR checklist_itr IN checklist LOOP
      --
      lc_checklist.EXTEND;
      lc_checklist(lc_checklist.COUNT) := checklist_itr.pair;
      --
    END LOOP;
    --
    IF lc_checklist.count = 0 THEN
      --
      x_status := 'FAILED';
      --
    ELSE
      --
      x_return_checklist := lc_checklist;
      x_status := 'SUCCESS';
      --
    END IF;
    --
  END get_checklist;
  --
  PROCEDURE validate_setup(p_seeded_vs IN VARCHAR2,
                           p_check_vs  IN VARCHAR2,
                           x_out_dir_name OUT VARCHAR2,
                           x_out_dir   OUT VARCHAR2,
                           x_oeda_user OUT NUMBER,
                           x_oeda_resp OUT NUMBER,
                           x_oeda_appl OUT NUMBER,
                           x_conc_sh   OUT VARCHAR2,
                           x_conc_app  OUT VARCHAR2,
                           x_conc_time OUT NUMBER,
                           x_del_file  OUT VARCHAR2,
                           x_status    OUT VARCHAR2,
                           x_error_msg OUT VARCHAR2) IS
    --
    lc_seeded_checklist sys.odcivarchar2list := sys.odcivarchar2list();
    lc_validate_status  VARCHAR2(1000);
    --
    lc_pair_check VARCHAR2(6000);
    lc_param      VARCHAR2(6000);
    lc_value      VARCHAR2(6000);
    lc_check_val  VARCHAR2(6000);
    ln_check_val  NUMBER;
    --
    ln_user_id    NUMBER;
    ln_resp_id    NUMBER;
    ln_app_id     NUMBER;
    lc_out_dir    VARCHAR2(15000);
    lc_conc_app   VARCHAR2(10000);
    --
    lc_error_msg    VARCHAR2(5000);
    ex_custom_issue EXCEPTION;
    --
  BEGIN
    --
    get_checklist(p_seeded_vs        => p_seeded_vs,
                  x_status           => lc_validate_status,
                  x_return_checklist => lc_seeded_checklist);
    --
    IF lc_validate_status = 'FAILED' THEN
      --
      lc_error_msg := 'Seeded Checklist Validation Failed.....';
      RAISE ex_custom_issue;
      --
    END IF;
    --
    --
    FOR lits_itr IN 1 .. lc_seeded_checklist.count LOOP
      --
      lc_pair_check := lc_seeded_checklist(lits_itr);
      
      lc_param      := regexp_substr(lc_pair_check, '[^=]+', 1, 1);
      lc_value      := regexp_substr(lc_pair_check, '[^=]+', 1, 2);
      --
      lc_check_val := check_if_process_enabled(lc_param,p_check_vs);
      log('Validating VS Parameter : ' || lc_param || ' : ' ||
                           lc_check_val);
      --
      IF lc_param = 'OEDA_PROCESS_ENABLE' AND upper(lc_check_val) != 'YES' THEN
        --
        lc_error_msg := 'validate_setup : OEDA_PROCESS_ENABLE paramter is not enabled';
        RAISE ex_custom_issue;
        --
      ELSIF lc_param != 'OEDA_PROCESS_ENABLE'  AND upper(lc_check_val) = 'VALUENOTSET' THEN
        --
        lc_error_msg := 'validate_setup : ' || lc_param || ' paramter is not set not set in VS';
        RAISE ex_custom_issue;
        --
      END IF;
      --------
      IF lc_param = 'OEDA_DIR' THEN
        --
        SELECT COUNT(*),
               directory_path
        INTO ln_check_val,
             lc_out_dir
        FROM all_directories
        WHERE directory_name = lc_check_val
        GROUP BY directory_path;
        --
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : ' || lc_param || ' not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_out_dir_name := lc_check_val;
        x_out_dir := lc_out_dir;
        --
      END IF;
      --------
      --
      IF lc_param = 'OEDA_USER' THEN
        --
        SELECT COUNT(*),
               user_id
        INTO ln_check_val,ln_user_id
        FROM apps.fnd_user
        WHERE user_name = lc_check_val
        GROUP BY user_id;
        --
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : ' || lc_param || ' not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_oeda_user := ln_user_id;
        --
      END IF;
      ---------
      IF lc_param = 'OEDA_RESP_NAME' THEN
        --
        SELECT COUNT(*),
               rvl.responsibility_id,
               rvl.application_id
        INTO ln_check_val,
             ln_resp_id,
             ln_app_id
        FROM apps.fnd_responsibility_vl rvl
        WHERE 1 = 1
        AND rvl.responsibility_name = lc_check_val
        GROUP BY rvl.responsibility_id,
                 rvl.application_id;
        --
        
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : ' || lc_param || ' not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_oeda_resp := ln_resp_id;
        x_oeda_appl := ln_app_id;
        --  
      END IF;
      ---------
      IF lc_param = 'OEDA_CONC_SH_NAME' THEN
        --
        SELECT count(*),fa.application_short_name
        INTO ln_check_val,lc_conc_app
        FROM apps.fnd_concurrent_programs    fcp,
             apps.fnd_concurrent_programs_tl fcpt,
             apps.fnd_executables            fe,
             apps.fnd_executables_tl         fet,
             apps.fnd_application            fa,
             apps.fnd_application_tl         fat
        WHERE fe.executable_id = fet.executable_id
        AND fcp.concurrent_program_id = fcpt.concurrent_program_id
        AND fcpt.language = fet.language
        AND fcp.executable_id = fe.executable_id
        AND fcp.executable_application_id = fe.application_id
        AND fcp.application_id = fa.application_id
        AND fa.application_id = fat.application_id
        AND fcpt.language = 'US'
        AND fcp.enabled_flag = 'Y'
        AND upper(fcp.concurrent_program_name) = lc_check_val
        GROUP BY fa.application_short_name;
        --
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : ' || lc_param || ' not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_conc_sh := lc_check_val;
        x_conc_app  := lc_conc_app;
        --  
      END IF;
      -------
      IF lc_param = 'OEDA_CONC_REQ_TIME' THEN
        --
        x_conc_time := TO_NUMBER(lc_check_val);        
        --
      END IF;
      --
      IF lc_param = 'OEDA_DEL_FILE' THEN
        --
        x_del_file := lc_check_val;     
        --
      END IF;
      ---------
      lc_check_val := NULL;
      ln_check_val := 0;
      lc_error_msg := NULL;
      lc_param := NULL;
      --
    END LOOP;
    --
    x_status := 'SUCCESS';
    --
  EXCEPTION
    --
    WHEN ex_custom_issue THEN
      --
      x_error_msg := lc_error_msg;
      x_status    := 'FAILED';
      --
    WHEN OTHERS THEN
      --
      x_error_msg := 'PL/SQL : Unexpected Error Occurred in validate_setup : ' ||
                     SQLERRM || ' : ' || dbms_utility.format_error_backtrace;
      x_status    := 'FAILED';
      --
  END validate_setup;
  --
  --
  FUNCTION check_if_process_enabled(p_check_var in VARCHAR2,
                                    p_check_vs  in VARCHAR2) RETURN VARCHAR2 IS
     --
     lc_check_val VARCHAR2(5000) := 'VALUENOTSET';
     --
   BEGIN
     --
     SELECT ffvt.description
       INTO lc_check_val
       FROM apps.fnd_flex_value_sets ffvs,
            apps.fnd_flex_values     ffv,
            apps.fnd_flex_values_tl  ffvt
      WHERE 1 = 1
        AND ffvs.flex_value_set_id = ffv.flex_value_set_id
        AND ffv.flex_value_id = ffvt.flex_value_id
        AND ffv.enabled_flag = 'Y'
        AND (ffv.end_date_active IS NULL or
            trunc(ffv.start_date_active) <= trunc(SYSDATE))
        AND (ffv.end_date_active IS NULL OR
            trunc(ffv.end_date_active) >= trunc(SYSDATE))
        AND ffvt.language = userenv('LANG')
        AND flex_value_set_name = p_check_vs
        AND ffv.flex_value = p_check_var;
     --
     IF lc_check_val IS NULL THEN
       lc_check_val := 'VALUENOTSET';
     END IF;
     RETURN lc_check_val;
     --
   END check_if_process_enabled;
  --
  FUNCTION wait_for_request(p_request_id   IN NUMBER,
                            p_timeout_secs IN NUMBER DEFAULT 120) RETURN VARCHAR2 IS
    --
    lc_conc_result BOOLEAN;
    lc_phase       VARCHAR2(80);
    lc_status      VARCHAR2(80);
    lc_dev_phase   VARCHAR2(30);
    lc_dev_status  VARCHAR2(30);
    lc_message     VARCHAR2(2000);
    ln_request_id   NUMBER := p_request_id;
    --
    l_start_time DATE := SYSDATE;
    --
  BEGIN
    --
    LOOP
      --
      IF (SYSDATE - l_start_time) * 86400 > p_timeout_secs THEN
        --
        lc_conc_result := FND_CONCURRENT.CANCEL_REQUEST(p_request_id, lc_message);
        RETURN 'TIMEOUT'; 
        --
      END IF;
      --
      lc_conc_result := fnd_concurrent.get_request_status(request_id     => ln_request_id,
                                                          appl_shortname => NULL,
                                                          program        => NULL,
                                                          phase          => lc_phase,
                                                          status         => lc_status,
                                                          dev_phase      => lc_dev_phase,
                                                          dev_status     => lc_dev_status,
                                                          message        => lc_message);
      --
      IF NOT lc_conc_result THEN
        --
        RETURN 'NOT_FOUND';
        --
      END IF;
      --
      IF lc_dev_phase = 'COMPLETE' THEN
        --
        IF lc_dev_status = 'NORMAL' THEN
          --
          RETURN 'SUCCESS';
          --
        ELSE
          --
          RETURN 'ERROR';
          --
        END IF;
        --
      END IF;
      --
      lc_dev_status := NULL;
      DBMS_SESSION.SLEEP(1);
      --
    END LOOP;
  
    RETURN 'SUCCESS';
    --
  END wait_for_request;
  --
  PROCEDURE get_ebs_artifact(p_component_type IN VARCHAR2,
                             p_file_name      IN VARCHAR2,
                             p_script         IN VARCHAR2,
                             p_run_mode       IN VARCHAR2,
                             x_file_content   OUT BLOB,
                             x_status         OUT VARCHAR2,
                             x_error_message  OUT VARCHAR2) IS
    --
    lc_component_type VARCHAR2(20000) := p_component_type;
    lc_real_file_name VARCHAR2(20000) := p_file_name;
    lc_script         VARCHAR2(32000) := p_script;
    ln_runmode        NUMBER := to_number(p_run_mode);
    lc_file_content   BFILE;
    lb_blob_file      BLOB;
    lc_error_message  VARCHAR2(32000);
    --
    lc_out_dir        VARCHAR2(5000);
    lc_out_dir_name   VARCHAR2(7000);
    ln_user_id        NUMBER;
    ln_resp_id        NUMBER;
    ln_app_id         NUMBER;
    lc_conc_sh        VARCHAR2(5000);
    lc_conc_app       VARCHAR2(5000);
    ln_conc_req_time  NUMBER;
    lc_del_file       VARCHAR2(5000);
    lc_validate_status VARCHAR2(5000);
    lc_validate_err    VARCHAR2(5000);
    --
    ln_request_id          NUMBER;
    lc_request_check       VARCHAR2(5000);
    --
    lc_err_message         VARCHAR2(30000);
    ex_custom_issue        EXCEPTION;
    --
  BEGIN
    --
    validate_setup(p_seeded_vs    => 'XX_OEDA_SEED_VALIDTION_VS',
                   p_check_vs     => 'XX_OEDA_USER_SET_VS',
                   x_out_dir      => lc_out_dir,
                   x_out_dir_name => lc_out_dir_name,
                   x_oeda_user    => ln_user_id,
                   x_oeda_resp    => ln_resp_id,
                   x_oeda_appl    => ln_app_id,
                   x_conc_sh      => lc_conc_sh,
                   x_conc_app     => lc_conc_app,
                   x_conc_time    => ln_conc_req_time,
                   x_del_file     => lc_del_file,
                   x_status       => lc_validate_status,
                   x_error_msg    => lc_validate_err);
    --
    IF lc_validate_status = 'FAILED' THEN
      --
      lc_err_message := lc_validate_err;
      RAISE ex_custom_issue;
      --
    END IF;
    --
    log(ln_user_id || ' / ' || ln_resp_id || ' / ' || ln_app_id);
    --
    apps.fnd_global.apps_initialize(user_id      => ln_user_id,
                                    resp_id      => ln_resp_id,
                                    resp_appl_id => ln_app_id);
    --
    log('Now running as ' || fnd_global.user_name || ' under ' || fnd_global.resp_name || '/' || fnd_global.application_name);
    --
    IF lc_script IS NULL THEN
      --
      lc_err_message := 'Script parameter is null.. ' || chr(10) || 'cannot proceed for execution...' || chr(10) ||
                        'aborting execution....';
      RAISE ex_custom_issue;
      --
    END IF;
    --
    -- Calling a Concurrent program to the script and place it in our temp dir.
    log('Calling Download utility Execution program...');
    log('Calling program : ' || lc_conc_sh);
    --
    ln_request_id := fnd_request.submit_request(application => lc_conc_app,
                                                program     => lc_conc_sh,
                                                start_time  => SYSDATE,
                                                sub_request => FALSE,
                                                argument1   => lc_out_dir,
                                                argument2   => lc_script,
                                                argument3   => ln_runmode);
    --
    IF ln_request_id = 0 THEN
      --
      lc_err_message := 'Failed to submit concurrent request: ' ||
                        fnd_message.get;
      RAISE ex_custom_issue;
      --
    END IF;
    --
    COMMIT;
    --
    log('Concurrent Request id : ' || ln_request_id);
    --
    lc_request_check := wait_for_request(p_request_id   => ln_request_id,
                                         p_timeout_secs => ln_conc_req_time);
    --
    IF lc_request_check = 'TIMEOUT' THEN
      --
      lc_err_message := 'wait_for_request : Concurrent program was terminated as it reached timeout time : ' ||
                        ln_conc_req_time;
      RAISE ex_custom_issue;
      --
    ELSIF lc_request_check = 'ERROR' THEN
      --
      lc_err_message := 'wait_for_request : Concurrent program execution was terminated with status : ' || lc_request_check;
      RAISE ex_custom_issue;
      --
    END IF;
    --
    lc_file_content   := bfilename(lc_out_dir_name, lc_real_file_name);
    --
    IF dbms_lob.fileexists(lc_file_content) = 1 THEN
      --
      dbms_lob.createtemporary(lb_blob_file, TRUE);
      dbms_lob.open(lc_file_content, dbms_lob.lob_readonly);
      dbms_lob.loadfromfile(lb_blob_file,
                            lc_file_content,
                            dbms_lob.getlength(lc_file_content));
      dbms_lob.close(lc_file_content);
      --
      x_file_content := lb_blob_file;
      x_status       := 'SUCCESS';
      --
      IF lc_del_file = 'YES' THEN
        --
        BEGIN
          --
          utl_file.fremove(lc_out_dir_name, lc_real_file_name);
          --
        EXCEPTION
          --
          WHEN OTHERS THEN
            --
            log('OEDA WARNING: Failed to delete temp file ' ||
                lc_real_file_name || ' from directory ' || lc_out_dir_name ||
                chr(10) || SQLERRM);
            --
        END;
      END IF;
      --
    ELSE
      --
      lc_err_message := 'get_ebs_artifact : BFILE Does not exists in DIR : ' ||
                        lc_out_dir_name || ' - ' || lc_real_file_name;
      RAISE ex_custom_issue;
      --
    END IF;
    --
  EXCEPTION
    --
    WHEN ex_custom_issue THEN
      --
      x_status        := 'FAILED';
      x_error_message := 'Oracle PL/SQL : IN get_ebs_artifact : ' ||
                         lc_err_message;
      --
    WHEN no_data_found THEN
      --
      x_status        := 'FAILED';
      x_error_message := 'Oracle PL/SQL : No Data Found Error Occurred in get_ebs_artifact : ' ||
                         SQLERRM || ' : ' ||
                         dbms_utility.format_error_backtrace;
      --
    WHEN OTHERS THEN
      --
      x_status        := 'FAILED';
      x_error_message := 'Oracle PL/SQL : Unexpected Error Occurred in get_ebs_artifact : ' ||
                         SQLERRM || ' : ' ||
                         dbms_utility.format_error_backtrace;
      --
  END get_ebs_artifact;

END XX_OEDA_DOWNLOAD_UTILITY;

CREATE OR REPLACE PACKAGE BODY XX_OEDA_DOWNLOAD_UTITLIY AS
  /*-------------------------------------------------------------------------------------------
  *********************************************************************************************
  Details : Package Body
  
  Package Name : XX_OEDA_DOWNLOAD_UTITLIY.pkb
  Description  : OEDA PL/SQL Package for OEDA
  Doc ID       : 
  
  =============================================================================================
  REM    Version     Revision Date           Developer             Change Description 
  ---    -------     ------------            ---------------       ------------------
  REM    1.0         03-JUNE-2025            Rohit Chaudhari       Initial Version
  *********************************************************************************************
  ---------------------------------------------------------------------------------------------*/
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
                           x_out_dir   OUT VARCHAR2,
                           x_oeda_user OUT NUMBER,
                           x_oeda_resp OUT NUMBER,
                           x_oeda_appl OUT NUMBER,
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
      dbms_output.put_line('Current : ' || lc_param || ' : ' ||
                           lc_check_val);
      --
      IF lc_param = 'OEDA_PROCESS_ENABLE' AND upper(lc_check_val) != 'YES' THEN
        --
        lc_error_msg := 'validate_setup : OEDA_PROCESS_ENABLE paramter is not enabled';
        RAISE ex_custom_issue;
        --
      ELSIF (lc_param = 'OEDA_DIR' OR lc_param = 'OEDA_USER' OR lc_param = 'OEDA_RESP_NAME') AND upper(lc_check_val) = 'VALUENOTSET' THEN
        --
        lc_error_msg := 'validate_setup : ' || lc_param || ' paramter is not set not set in VS';
        RAISE ex_custom_issue;
        --
      END IF;
      --------
      IF lc_param = 'OEDA_DIR' THEN
        --
        SELECT COUNT(*)
        INTO ln_check_val
        FROM all_directories
        WHERE directory_name = lc_check_val;
        --
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : OEDA_DIR is not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_out_dir := lc_check_val;
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
          lc_error_msg := 'validate_setup :  OEDA_USER is not defined/available in Oracle';
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
        WHERE responsibility_name = lc_check_val
        GROUP BY rvl.responsibility_id,
                 rvl.application_id;
        --
        IF ln_check_val = 0 THEN
          --
          lc_error_msg := 'validate_setup : OEDA_RESP_NAME not defined/available in Oracle';
          RAISE ex_custom_issue;
          --
        END IF;
        --
        x_oeda_resp := ln_resp_id;
        x_oeda_appl := ln_app_id;
        --  
      END IF;
      ---------
      lc_check_val := NULL;
      ln_check_val := 0;
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
  --
  PROCEDURE get_ebs_artifact(p_component_type IN VARCHAR2,
                             p_component_name IN VARCHAR2,
                             p_script         IN VARCHAR2,
                             x_file_content   OUT BLOB,
                             x_status         OUT VARCHAR2,
                             x_error_message  OUT VARCHAR2) IS
    --
    lc_component_type VARCHAR2(20000) := p_component_type;
    lc_component_name VARCHAR2(20000) := p_component_name;
    lc_script         VARCHAR2(32000) := p_script;
    lc_file_content   BLOB;
    lc_error_message  VARCHAR2(32000);
    --
    lc_out_dir        VARCHAR2(5000);
    ln_user_id        NUMBER;
    ln_resp_id        NUMBER;
    ln_app_id         NUMBER;
    lc_validate_status VARCHAR2(5000);
    lc_validate_err    VARCHAR2(5000);
    --
    ln_request_id          NUMBER;
    --
    lc_err_message         VARCHAR2(30000);
    ex_custom_issue        EXCEPTION;
    --
  BEGIN
    --
    validate_setup(p_seeded_vs => 'XX_OEDA_SEED_VALIDTION_VS',
                   p_check_vs  => 'XX_OEDA_USER_SET_VS',
                   x_out_dir   => lc_out_dir,
                   x_oeda_user => ln_user_id,
                   x_oeda_resp => ln_resp_id,
                   x_oeda_appl => ln_app_id,
                   x_status    => lc_validate_status,
                   x_error_msg => lc_validate_err);
    --
    IF lc_validate_status = 'FAILED' THEN
      --
      lc_err_message := lc_validate_err;
      RAISE ex_custom_issue;
      --
    END IF;
    --
    dbms_output.put_line(ln_user_id || ' / ' || ln_resp_id || ' / ' || ln_app_id);
    --
    apps.fnd_global.apps_initialize(user_id      => ln_user_id,
                                    resp_id      => ln_resp_id,
                                    resp_appl_id => ln_app_id);
    --
    dbms_output.put_line('Now running as ' || fnd_global.user_name || ' under ' || fnd_global.resp_name || '/' || fnd_global.application_name);
    --
    IF lc_script IS NULL THEN 
      --
      lc_err_message := 'Script parameter is null.. ' || chr(10) || 'cannot proceed for execution...' || chr(10) || 'aborting execution....';
      RAISE ex_custom_issue;
      --
    END IF;
    --
    -- Calling a Concurrent program to the script and place it in our temp dir.
    --
    x_status := 'SUCCESS';
    --
  EXCEPTION
    --
    WHEN ex_custom_issue THEN
      --
      x_status        := 'FAILED';
      x_error_message := 'Oracle PL/SQL : IN get_ebs_artifact' || lc_err_message;
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

END XX_OEDA_DOWNLOAD_UTITLIY;
/

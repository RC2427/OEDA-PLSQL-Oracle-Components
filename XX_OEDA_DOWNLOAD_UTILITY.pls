CREATE OR REPLACE PACKAGE XX_OEDA_DOWNLOAD_UTILITY AS
  /* $Header: $ */
  /*#
  * This is Package for OEDA Download utility
  * @rep:scope public
  * @rep:product FND
  * @rep:lifecycle active
  * @rep:displayname XX_OEDA_DOWNLOAD_UTILITY
  * @rep:compatibility S
  * @rep:category BUSINESS_ENTITY XX_OEDA
  */
  
  /*#
  * Procedure to download oracle artifacts
  * @param p_component_type VARCHAR2
  * @param p_file_name VARCHAR2
  * @param p_script VARCHAR2
  * @param x_file_content BLOB
  * @param x_status VARCHAR2
  * @param x_error_message VARCHAR2
  * @rep:displayname Download Utitlity Procedure 
  * @rep:scope public
  * @rep:lifecycle active
  * @rep:category BUSINESS_ENTITY XX_OEDA
  */
  PROCEDURE get_ebs_artifact(p_component_type IN VARCHAR2,
                             p_file_name      IN VARCHAR2,
                             p_script         IN VARCHAR2,
                             p_run_mode       IN VARCHAR2,
                             x_file_content   OUT BLOB,
                             x_status         OUT VARCHAR2,
                             x_error_message  OUT VARCHAR2);
  --                           
  FUNCTION check_if_process_enabled(p_check_var in VARCHAR2,
                                    p_check_vs  in VARCHAR2) RETURN VARCHAR2;

END XX_OEDA_DOWNLOAD_UTILITY;


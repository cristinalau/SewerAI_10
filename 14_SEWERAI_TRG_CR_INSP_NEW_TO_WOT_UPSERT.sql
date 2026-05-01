CREATE OR REPLACE TRIGGER TRG_CR_INSP_NEW_TO_WOT_UPSERT
AFTER INSERT OR UPDATE OF FEED_STATUS
ON CUSTOMERDATA.EPSEWERAI_CR_INSPECT
FOR EACH ROW
WHEN (NEW.FEED_STATUS = 'NEW')
DECLARE
  v_workorder_uuid RAW(16);
  v_task_uuid      RAW(16);
BEGIN
  -- convert WORK_ORDER_UUID
  v_workorder_uuid := HEXTORAW(UPPER(REPLACE(:NEW.WORK_ORDER_UUID, '-', '')));

  -- get TASK_UUID from VIEW (THIS IS THE FIX)
  SELECT WORK_ORDER_TASK_UUID
  INTO v_task_uuid
  FROM CUSTOMERDATA.SEWERAI_INSPECTIONS_V v
  WHERE v.WORK_ORDER_UUID = v_workorder_uuid
    AND ROWNUM = 1;

  -- try update first
  UPDATE CUSTOMERDATA.EPSEWERAI_WOT_STG stg
     SET stg.FEED_STATUS = 'UPDATED'
   WHERE stg.WORKORDER_UUID = v_workorder_uuid;

  -- if not exist ? insert
  IF SQL%ROWCOUNT = 0 THEN
    INSERT INTO CUSTOMERDATA.EPSEWERAI_WOT_STG (
      TASK_UUID,
      WORKORDER_UUID,
      WONUMBER,
      TASKNUMBER,
      WOTASKTITLE,
      FEED_STATUS
    )
    VALUES (
      v_task_uuid,
      v_workorder_uuid,
      REGEXP_SUBSTR(:NEW.WORKORDER, '^[^.]+'),
      TO_NUMBER(REGEXP_SUBSTR(:NEW.WORKORDER, '[^.]+$')),
      :NEW.PROJECT,
      'UPDATED'
    );
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- nothing in view ? skip (important to avoid crashes)
    NULL;
END;
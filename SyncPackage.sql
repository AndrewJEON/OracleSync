spool script_platform_syn.log

prompt
prompt Create Tablespace GEOSHARE_SUB_PLATFORM and User GEOSHARE_SUB_PLATFORM
prompt ======================================================================
prompt
CREATE TABLESPACE "GEOSHARE_SUB_PLATFORM" 
    LOGGING 
    DATAFILE 'C:\app\Administrator\oradata\orcl\GEOSHARE_SUB_PLATFORM.dbf' SIZE 200M
   AUTOEXTEND
    ON NEXT  100M MAXSIZE UNLIMITED EXTENT MANAGEMENT LOCAL 
    SEGMENT SPACE MANAGEMENT  AUTO ;
	
create user GEOSHARE_SUB_PLATFORM
  identified by "admin" 
  default tablespace GEOSHARE_SUB_PLATFORM
  temporary tablespace TEMP
  profile DEFAULT;
-- Grant/Revoke role privileges 
grant connect to GEOSHARE_SUB_PLATFORM with admin option;
grant dba to GEOSHARE_SUB_PLATFORM with admin option;
grant exp_full_database to GEOSHARE_SUB_PLATFORM with admin option;
grant imp_full_database to GEOSHARE_SUB_PLATFORM with admin option;
grant resource to GEOSHARE_SUB_PLATFORM with admin option;
-- Grant/Revoke system privileges 
grant unlimited tablespace to GEOSHARE_SUB_PLATFORM with admin option;

prompt
prompt Creating table BRANCH_PLATFORM_TABLE_SYN
prompt ========================================
prompt
create table BRANCH_PLATFORM_TABLE_SYN
(
  TABLENAME VARCHAR2(30) not null,
  SYNFLAG   NUMBER(1) default 1 not null,
  DATATYPE	NUMBER(20) 
)
;
-- Add comments to the table 
comment on table BRANCH_PLATFORM_TABLE_SYN
  is '数据库同步信息表';
-- Add comments to the columns 
comment on column BRANCH_PLATFORM_TABLE_SYN.TABLENAME
  is '数据库表名';
comment on column BRANCH_PLATFORM_TABLE_SYN.SYNFLAG
  is '是否同步标识，0表示不同步，1表示同步';
comment on column BRANCH_PLATFORM_TABLE_SYN.DATATYPE
  is '资源类型';
---将需要同步的表名在此加入表中

prompt
prompt Creating table OM_DATACHGINFO
prompt =============================
prompt
create table OM_DATACHGINFO
(
  ID          NUMBER(20) not null,
  TABNAME     VARCHAR2(64),
  RECORDID    ROWID,
  PRIKEYVALUE VARCHAR2(512),
  CHGTYPE     NUMBER(1),
  UPDATEVALUE VARCHAR2(4000)
)
;
-- Add comments to the table 
comment on table OM_DATACHGINFO
  is '数据缓存表';
-- Add comments to the columns 
comment on column OM_DATACHGINFO.ID
  is '流水号';
comment on column OM_DATACHGINFO.TABNAME
  is '表名';
comment on column OM_DATACHGINFO.RECORDID
  is 'rowid';
comment on column OM_DATACHGINFO.PRIKEYVALUE
  is '变化表主键';
comment on column OM_DATACHGINFO.CHGTYPE
  is '变化类型';
comment on column OM_DATACHGINFO.UPDATEVALUE
  is '变化SQL代码';
alter table OM_DATACHGINFO add constraint PK_OM_DATACHGINFO primary key (ID);

prompt
prompt Creating directory SYN_DATA_EXPORT_SQL_DIR
prompt ==========================================
prompt
--保存sql文件的本地路径
create or replace directory SYN_DATA_EXPORT_SQL_DIR
  as 'C:\\sqltext';
  
prompt
prompt Creating sequence SEQ_SUBSYS_DATA_SYN
prompt =====================================
prompt
-- 生成的sql语句编号序列
create sequence SEQ_SUBSYS_DATA_SYN
minvalue 1
maxvalue 99999999999999999999
start with 1
increment by 1
cache 20
order;  

prompt
prompt Creating sequence SEQ_OM_DATACHGINFO
prompt ====================================
prompt
--数据缓存表序列
create sequence SEQ_OM_DATACHGINFO
minvalue 1
maxvalue 99999999999999999999
start with 1
increment by 1
cache 20
order;

prompt
prompt Creating sequence SEQ_LOB_DATA_SYN
prompt ==================================
prompt
-- LOB(clob/blob)文件编号序号 
create sequence SEQ_LOB_DATA_SYN
minvalue 1
maxvalue 99999999999999999999
start with 1
increment by 1
cache 20
order;

prompt
prompt Creating package Pkg_Onemap
prompt ===========================
prompt
CREATE OR REPLACE PACKAGE Pkg_Onemap
 AS
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Update_Varchar2valstr
  参数解释：Newval--更新的值，Oldval--原来的值，
			Colname--字段名，Loopcount--字段序列号，
			Updvalstr--组织的更新sql
  功能描述：组织varchar类型字段的更新sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Varchar2valstr(Newval    IN VARCHAR2,
                                     Oldval    IN VARCHAR2,
                                     Colname   IN VARCHAR2,
                                     Loopcount IN OUT NUMBER,
                                     Updvalstr IN OUT VARCHAR2);

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Update_Numvalstr
  参数解释：Newval--更新的值，Oldval--原来的值，
			Colname--字段名，Loopcount--字段序列号，
			Updvalstr--组织的更新sql
  功能描述：组织number类型字段的更新sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Numvalstr(Newval    IN NUMBER,
                                Oldval    IN NUMBER,
                                Colname   IN VARCHAR2,
                                Loopcount IN OUT NUMBER,
                                Updvalstr IN OUT VARCHAR2);

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Update_Datevalstr
  参数解释：Newval--更新的值，Oldval--原来的值，
			Colname--字段名，Loopcount--字段序列号，
			Updvalstr--组织的更新sql
  功能描述：组织date类型字段的更新sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Datevalstr(Newval    IN DATE,
                                 Oldval    IN DATE,
                                 Colname   IN VARCHAR2,
                                 Loopcount IN OUT NUMBER,
                                 Updvalstr IN OUT VARCHAR2);
                                 
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Update_Blobvar
  参数解释：Newval--更新的值，Colname--更新的字段名，
			Loopcount--字段所在列的序号，Updvalstr--组织的更新sql，
			Pkvalue--主键，Tabname--数据库表名
  功能描述：组织BLOB字段的更新语句，并将BLOB字段保存到本地
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Blobvar(Newval    IN BLOB,
                              Colname   IN VARCHAR2,
                              Loopcount IN OUT NUMBER,
                              Updvalstr IN OUT VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Tabname IN VARCHAR2);                                 

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Update_Clobvar
  参数解释：Newval--更新的值，Colname--更新的字段名，
			Loopcount--字段所在列的序号，Updvalstr--组织的更新sql，
			Pkvalue--主键，Tabname--数据库表名
  功能描述：组织CLOB字段的更新语句，并将CLOB字段保存到本地
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Clobvar(Newval    IN CLOB,
                              Colname   IN VARCHAR2,
                              Loopcount IN OUT NUMBER,
                              Updvalstr IN OUT VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Tabname IN VARCHAR2);
                              
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Buildup_Delsql
  参数解释：Tabname--数据库表名，Pkvalue--主键，Delsql--删除记录生成的sql
  功能描述：对删除记录生成的sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Delsql(Tabname IN VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Delsql  OUT VARCHAR2);

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Buildup_Inssql
  参数解释：Tabname--数据库表名，Pkvalue--主键，
			Sqlcolstr--所有字段名，Sqlcolvalue--生成的插入sql
  功能描述：对插入记录生成sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Inssql(Tabname   IN VARCHAR2,
                              Pkvalue   IN VARCHAR2,
                              Sqlcolstr OUT VARCHAR2,
                              --纯列STR，逗号分割
                              Sqlcolvalue OUT VARCHAR2
                              --纯值STR,逗号分割
                              );

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Buildup_Updsql
  参数解释：Tabname--数据库表名，Pkvalue--主键，
			Updatevalue--更新值，Updatesql--生成的更新sql
  功能描述：对更新记录生成sql
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Updsql(Tabname     IN VARCHAR2,
                              Pkvalue     IN VARCHAR2,
                              Updatevalue IN VARCHAR2,
                              Updatesql   OUT VARCHAR2);
							  
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Buildup_Synsql
  参数解释：
  功能描述：进行同步，生成同步脚本。
  ---------------------------------------------------------------------------------------*/
  PROCEDURE  OM_Buildup_Synsql;              

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Ins_Datachginfo
  参数解释：i_Tabname--数据库表名，i_Rowid--表记录的行号标识，
			i_Pk_Val--主键字符串，i_Type--变化类型(增/删/改)，
			i_Upd_Val--更新的字符串
  功能描述：在数据缓存表中保存被监控表中的变化记录
  ---------------------------------------------------------------------------------------*/  
  PROCEDURE OM_Ins_Datachginfo(i_Tabname IN VARCHAR2,
                               i_Rowid   IN ROWID,
                               i_Pk_Val  IN VARCHAR2,
                               i_Type    IN INTEGER,
                               i_Upd_Val VARCHAR2);                
                
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Create_Syntable_Trg
  参数解释：Tabname--数据库表名
  功能描述：给需要同步的表创建触发器
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Create_Syntable_Trg(Tabname IN VARCHAR2);

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Close_Triggle
  参数解释：Tabname--数据库表名
  功能描述：关闭一个库表上的触发器
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Close_Triggle(Tabname IN VARCHAR2);
  
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Dump_BLOB
  参数解释：i_Field_Name,blob字段名；i_Table_Name,表名；i_Pk_Val,主键字符串；
            o_Blob_Name,输出本地文件名；            
  功能描述：将表中的BLOB字段保存到本地文件
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Dump_BLOB (i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2,
                          i_Blob_Name  IN VARCHAR2);  

  /*-------------------------------------------------------------------------------------
  过程名称：OM_Load_BLOB
  参数解释：i_Blob_Name,输入的本地文件名；i_Field_Name,blob字段名；
            i_Table_Name,表名；i_Pk_Val,主键字符串;            
  功能描述：将本地文件保存到表中的BLOB字段中
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Load_BLOB (i_Blob_Name  IN VARCHAR2,
                          i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2);  
                          
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Dump_CLOB
  参数解释：i_Field_Name,clob字段名；i_Table_Name,表名；i_Pk_Val,主键字符串；
            o_Clob_Name,输出本地文件名；            
  功能描述：将表中的CLOB字段保存到本地文件
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Dump_CLOB (i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2,
                          i_Clob_Name  IN VARCHAR2);
    
  /*-------------------------------------------------------------------------------------
  过程名称：OM_Blob_Block
  参数解释：i_Sql_Stat,需要解析的sql语句；
            o_Blob_Block,输出的blob字段语句块；            
  功能描述：将SQL字符串中有关blob字段的内容截取出来
  ---------------------------------------------------------------------------------------*/
  PROCEDURE OM_Blob_Block(i_Sql_Stat   IN  VARCHAR2,
                          o_Blob_Block OUT VARCHAR2,
                          o_End_Loc    OUT INTEGER);
						  
END Pkg_Onemap;
/

prompt
prompt Creating package body Pkg_Onemap
prompt ================================
prompt
CREATE OR REPLACE PACKAGE BODY Pkg_Onemap
  AS
  
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Varchar2valstr(Newval    IN VARCHAR2,
                                     Oldval    IN VARCHAR2,
                                     Colname   IN VARCHAR2,
                                     Loopcount IN OUT NUMBER,
                                     Updvalstr IN OUT VARCHAR2) IS
    Nv             VARCHAR2(32767);
    Ov             VARCHAR2(32767);
    v_Update_Value VARCHAR2(32767);
    v_Len          NUMBER;
    v_Upd_Count    NUMBER;
  BEGIN
    IF (Newval IS NULL AND
       Oldval IS NULL) THEN
      RETURN;
    END IF;
    IF (Newval IS NOT NULL AND
       Oldval IS NOT NULL AND
       Newval = Oldval) THEN
      RETURN;
    END IF;
    Nv             := Newval;
    Ov             := Oldval;
    v_Update_Value := Updvalstr;
    v_Upd_Count    := Loopcount;
    IF (Ov IS NULL OR Nv IS NULL OR
       Nv <> Ov) THEN
      IF (v_Upd_Count > 0) THEN
        IF (Nv IS NULL) THEN
          v_Update_Value := v_Update_Value || ',' ||
                            Colname ||
                            ' = null';
        ELSE
          --zhangsheng add 2008-02-18 解决赋值时，返回字符串累加后超过4000，产生异常
          v_Len := Length(Nv);
          IF (v_Len > 1500) THEN
            v_Len := 1500;
            Nv    := Substrb(Nv,
                             1,
                             v_Len);
          END IF;
          v_Update_Value := v_Update_Value || ',' ||
                            Colname ||
                            '=''' || Nv || '''';
        END IF;
      ELSE
        IF (Nv IS NULL) THEN
          v_Update_Value := Colname ||
                            ' = null';
        ELSE
          --zhangsheng add 2008-02-18 解决赋值时，返回字符串累加后超过4000，产生异常
          v_Len := Length(Nv);
          IF (v_Len > 1500) THEN
            v_Len := 1500;
            Nv    := Substrb(Nv,
                             1,
                             v_Len);
          END IF;
          v_Update_Value := Colname ||
                            '=''' || Nv || '''';
        END IF;
      END IF;
      v_Upd_Count := v_Upd_Count + 1;
    END IF;
    Loopcount := v_Upd_Count;
    --feng add 2008-01-23 解决赋值时，字符缓冲区太小，产生异常
    v_Len := Length(v_Update_Value);
    IF (v_Len > 4000) THEN
      v_Len          := 4000;
      v_Update_Value := Substrb(v_Update_Value,
                                1,
                                v_Len);
    END IF;
    Updvalstr := v_Update_Value;
 END OM_Update_Varchar2valstr;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Numvalstr(Newval    IN NUMBER,
                                Oldval    IN NUMBER,
                                Colname   IN VARCHAR2,
                                Loopcount IN OUT NUMBER,
                                Updvalstr IN OUT VARCHAR2) IS
    Nv             NUMBER;
    Ov             NUMBER;
    v_Update_Value VARCHAR2(32767);
    v_Upd_Count    NUMBER;
  BEGIN
    IF (Newval IS NULL AND
       Oldval IS NULL) THEN
      RETURN;
    END IF;
    IF (Newval IS NOT NULL AND
       Oldval IS NOT NULL AND
       Newval = Oldval) THEN
      RETURN;
    END IF;
    Nv             := Newval;
    Ov             := Oldval;
    v_Update_Value := Updvalstr;
    v_Upd_Count    := Loopcount;
    IF (Ov IS NULL OR Nv IS NULL OR
       Nv <> Ov) THEN
      IF (v_Upd_Count > 0) THEN
        IF (Nv IS NULL) THEN
          v_Update_Value := v_Update_Value || ',' ||
                            Colname ||
                            ' = null';
        ELSE
          Nv             := Round(Nv, 8); --zhangsheng add 2008-02-18 解决赋值时，返回字符串累加后超过4000，产生异常
          v_Update_Value := v_Update_Value || ',' ||
                            Colname || '=' || Nv;
        END IF;
      ELSE
        IF (Nv IS NULL) THEN
          v_Update_Value := Colname ||
                            ' = null';
        ELSE
          Nv             := Round(Nv, 8); --zhangsheng add 2008-02-18 解决赋值时，返回字符串累加后超过4000，产生异常
          v_Update_Value := Colname || '=' || Nv;
        END IF;
      END IF;
      v_Upd_Count := v_Upd_Count + 1;
    END IF;
    Loopcount := v_Upd_Count;
    Updvalstr := v_Update_Value;
  END OM_Update_Numvalstr;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Datevalstr(Newval    IN DATE,
                                 Oldval    IN DATE,
                                 Colname   IN VARCHAR2,
                                 Loopcount IN OUT NUMBER,
                                 Updvalstr IN OUT VARCHAR2) IS
    Nv             DATE;
    Ov             DATE;
    v_Update_Value VARCHAR2(32767);
    v_Upd_Count    NUMBER;
  BEGIN
    IF (Newval IS NULL AND
       Oldval IS NULL) THEN
      RETURN;
    END IF;
    IF (Newval IS NOT NULL AND
       Oldval IS NOT NULL AND
       Newval = Oldval) THEN
      RETURN;
    END IF;
    Nv             := Newval;
    Ov             := Oldval;
    v_Update_Value := Updvalstr;
    v_Upd_Count    := Loopcount;
    IF (Ov IS NULL OR Nv IS NULL OR
       Nv <> Ov) THEN
      IF (v_Upd_Count > 0) THEN
        IF (Nv IS NULL) THEN
          v_Update_Value := v_Update_Value || ',' ||
                            Colname ||
                            ' = null';
        ELSE
          v_Update_Value := v_Update_Value || ',' ||
                            Colname ||
                            '=TO_DATE(''' ||
                            To_Char(Nv,
                                    'YYYY-MM-DD HH24:MI:SS') ||
                            ''', ''YYYY-MM-DD HH24:MI:SS'')';
        END IF;
      ELSE
        IF (Nv IS NULL) THEN
          v_Update_Value := Colname ||
                            ' = null';
        ELSE
          v_Update_Value := Colname ||
                            '=TO_DATE(''' ||
                            To_Char(Nv,
                                    'YYYY-MM-DD HH24:MI:SS') ||
                            ''', ''YYYY-MM-DD HH24:MI:SS'')';
        END IF;
      END IF;
      v_Upd_Count := v_Upd_Count + 1;
    END IF;
    Loopcount := v_Upd_Count;
    Updvalstr := v_Update_Value;
  END OM_Update_Datevalstr;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Blobvar(Newval    IN BLOB,
                              Colname   IN VARCHAR2,
                              Loopcount IN OUT NUMBER,
                              Updvalstr IN OUT VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Tabname IN VARCHAR2) IS
    Nv             BLOB;
    v_Update_Value VARCHAR2(32767);
    v_Upd_Count    NUMBER;  
    v_blob_name    VARCHAR2(30); 
    v_Name_Flag    VARCHAR2(14);         -- 时间戳标识                                    
  BEGIN
    -- 安全检查
    IF (Newval IS NULL AND
       Pkvalue IS NULL OR
       Tabname IS NULL) THEN
      RETURN;
    END IF;

    Nv             := Newval;
    v_Update_Value := Updvalstr;
    v_Upd_Count    := Loopcount;    

    IF (v_Upd_Count > 0) THEN -- 不是第一个字段
      IF (Nv IS NULL) THEN    -- 将原始内容清空
        v_Update_Value := v_Update_Value || ',' ||
                          Colname ||
                          ' = LOB(''empty_blob()'')';
      ELSE
        -- 首先将字段内容保存到本地
         SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Name_Flag from Dual;
        v_blob_name := 'BLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Name_Flag || '.RAW';
--        OM_Dump_BLOB(Colname, Tabname, Pkvalue, v_blob_name);
        
        -- 组织updae字符串       
        v_Update_Value := v_Update_Value || ',' ||
                          Colname ||
                          '=LOB(''' || v_blob_name || '''';
      END IF;
    ELSE  -- 第一个字段
      IF (Nv IS NULL) THEN
        v_Update_Value := Colname ||
                          ' = LOB(''empty_blob()'')';
      ELSE
        SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Name_Flag from Dual;
        v_blob_name := 'BLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Name_Flag || '.RAW';
--        OM_Dump_BLOB(Colname, Tabname, Pkvalue, v_blob_name);
        
        -- 组织updae字符串       
        v_Update_Value := Colname ||
                          '=LOB(''' || v_blob_name || '''';
      END IF;
    END IF;
    v_Upd_Count := v_Upd_Count + 1;

    Loopcount := v_Upd_Count;
    Updvalstr := v_Update_Value;    
    
  END OM_Update_Blobvar;
  
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Update_Clobvar(Newval    IN CLOB,
                              Colname   IN VARCHAR2,
                              Loopcount IN OUT NUMBER,
                              Updvalstr IN OUT VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Tabname IN VARCHAR2) IS
    Nv             CLOB;
    v_Update_Value VARCHAR2(32767);
    v_Upd_Count    NUMBER;  
    v_blob_name    VARCHAR2(30); 
    v_Name_Flag    VARCHAR2(14);         -- 时间戳标识                                    
  BEGIN
    -- 安全检查
    IF (Newval IS NULL AND
       Pkvalue IS NULL OR
       Tabname IS NULL) THEN
      RETURN;
    END IF;

    Nv             := Newval;
    v_Update_Value := Updvalstr;
    v_Upd_Count    := Loopcount;    

    IF (v_Upd_Count > 0) THEN -- 不是第一个字段
      IF (Nv IS NULL) THEN    -- 将原始内容清空
        v_Update_Value := v_Update_Value || ',' ||
                          Colname ||
                          ' = LOB(''empty_clob()'')';
      ELSE
        -- 首先将字段内容保存到本地
        SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Name_Flag from Dual;
        v_blob_name := 'CLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Name_Flag || '.TXT';
--        OM_Dump_CLOB(Colname, Tabname, Pkvalue, v_blob_name);
        
        -- 组织updae字符串       
        v_Update_Value := v_Update_Value || ',' ||
                          Colname ||
                          '=LOB(''' || v_blob_name || ''')';
      END IF;
    ELSE  -- 第一个字段
      IF (Nv IS NULL) THEN
        v_Update_Value := Colname ||
                          ' = LOB(''empty_clob()'')';
      ELSE
        SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Name_Flag from Dual;
        v_blob_name := 'CLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Name_Flag || '.TXT';
--        OM_Dump_CLOB(Colname, Tabname, Pkvalue, v_blob_name);
                
        v_Update_Value := Colname ||
                          '=LOB(''' || v_blob_name || ''')';
      END IF;
    END IF;
    v_Upd_Count := v_Upd_Count + 1;

    Loopcount := v_Upd_Count;
    Updvalstr := v_Update_Value;    
    
  END OM_Update_Clobvar;                              
                                
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Delsql(Tabname IN VARCHAR2,
                              Pkvalue IN VARCHAR2,
                              Delsql  OUT VARCHAR2) IS
    v_Errtxt VARCHAR2(200);

  BEGIN
    Delsql := 'DELETE ' || Tabname ||
              ' WHERE ' || Pkvalue;
  EXCEPTION
    WHEN OTHERS THEN
      v_Errtxt := SQLERRM;
  END OM_Buildup_Delsql;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Inssql(Tabname   IN VARCHAR2,
                              Pkvalue   IN VARCHAR2,
                              Sqlcolstr OUT VARCHAR2,
                              --纯列STR，逗号分割
                              Sqlcolvalue OUT VARCHAR2
                              --纯值STR,逗号分割
                              ) IS
    v_Colstr VARCHAR2(32767); --列名组成的串
    v_Exestr VARCHAR2(32767);
    v_Valstr VARCHAR2(32767);
    v_Comma  VARCHAR(100);
    v_Links  VARCHAR(100);
    v_Loop   INT := 0;

    v_Length INT := 0;

    v_Colname VARCHAR2(100);

    v_Errtxt VARCHAR2(200);

    v_Tmp            VARCHAR2(32767);
    Vc_Sql_Part      VARCHAR2(32767);
    Vi_Sql_Val_Parts INTEGER := 0; --动态SQL语句V_EXESTR执行之后的into变量的个数
    Vi_Parts_Count   INTEGER := 0;

    Vi_Pre_Cols_Len INTEGER := 0;

    v_Into1  VARCHAR2(32767);
    v_Into2  VARCHAR2(32767);
    v_Into3  VARCHAR2(32767);
    v_Into4  VARCHAR2(32767);
    v_Into5  VARCHAR2(32767);
    v_Into6  VARCHAR2(32767);
    v_Into7  VARCHAR2(32767);
    v_Into8  VARCHAR2(32767);
    v_Into9  VARCHAR2(32767);
    v_Into10 VARCHAR2(32767);
    
    v_Blob_Names    VARCHAR2(300);       -- blob字段名字符串
    v_Blob_Num      INTEGER := 0;        -- blob字段个数
    v_Blob_Flag     INTEGER := 0;        -- blob字段标识(0表示当前字段不是blob类型，1表示是blob类型)
    
    v_Clob_Names    VARCHAR2(300);       -- clob字段名字符串
    v_Clob_Num      INTEGER := 0;        -- clob字段个数
    v_Clob_Flag     INTEGER := 0;        -- clob字段标识(0表示当前字段不是blob类型，1表示是clob类型)
    
    v_Tmp_Name      VARCHAR2(30);        -- 字段名临时保存变量；

    v_File_Loc      BFILE := NULL;       -- 文件保存位置    
    v_File_Exist    BOOLEAN := FALSE;    -- 文件是否存在标识
    v_Loc           INTEGER := 0;        -- 位置标识
    v_Time_Flag     VARCHAR2(14);        -- 时间戳标识    
  BEGIN
    v_Tmp := 'SELECT ';
    FOR c IN (SELECT c.Column_Name,
                     c.Data_Type,
                     c.Data_Length
                FROM User_Tab_Cols c
               WHERE c.Table_Name =
                     Tabname
               ORDER BY c.Data_Length) LOOP

      v_Colname       := c.Column_Name;
      Vi_Pre_Cols_Len := Vi_Pre_Cols_Len +
                         c.Data_Length;
      v_Loop          := v_Loop + 1;
      IF (v_Loop > 1) THEN
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Comma := ', ';
      ELSE
        v_Comma := '';
      END IF;

      CASE c.Data_Type
        WHEN 'VARCHAR2' THEN
          /*VC_SQL_PART := 'decode(' || C.COLUMN_NAME ||
          ',null,''null'',CHR(39) || ' || C.COLUMN_NAME ||
          '||CHR(39))';*/
          --zhou modified at 2007.11.4
          --修改原因，增加了对字符串里面包含特殊字符'''和'&'的处理
          --其它字符暂时没有考虑。
          Vc_Sql_Part := 'decode(' ||
                         c.Column_Name ||
                         ',null,''null'',CHR(39)||' ||
                         'REPLACE(REPLACE(' ||
                         c.Column_Name ||
                         ', '''''''',''''''||CHR(39)||''''''),''&'',''''''||CHR(38)||'''''')||CHR(39))';
        WHEN 'DATE' THEN
          Vc_Sql_Part := 'decode(' ||
                         c.Column_Name ||
                         ',null,''null'',' ||
                         '''TO_DATE(' ||
                         '''''''||to_char(' ||
                         c.Column_Name ||
                         ',''YYYY-MM-DD HH24:MI:SS'')||'''''',''''YYYY-MM-DD HH24:MI:SS'''')'')';
        WHEN 'BLOB' THEN
          v_Blob_Flag := 1; 
          v_Blob_Num := v_Blob_Num + 1;
          
          IF (v_Blob_Num = 1) THEN   -- blob字段名字符串
            v_Blob_Names := v_Colname;
          ELSE 
            v_Blob_Names := v_Blob_Names || v_Comma || 
                     v_Colname;
          END IF;
        WHEN 'CLOB' THEN
          v_Clob_Flag := 1;
          v_Clob_Num := v_Clob_Num + 1;
          
          IF (v_Clob_Num = 1) THEN
            v_Clob_Names := v_Colname;
          ELSE
            v_Clob_Names := v_Clob_Names || v_Comma || 
                         v_Colname;  
          END IF;                        
        ELSE
          Vc_Sql_Part := 'decode(' ||
                         c.Column_Name ||
                         ',null,''null'',' ||
                         c.Column_Name || ')';
      END CASE;
      
      IF ( v_Blob_Flag = 0 AND v_Clob_Flag = 0) THEN      -- 非blob字段名字符串
        v_Colstr := v_Colstr || v_Comma ||
                 c.Column_Name;
      ELSE       
        v_Blob_Flag := 0;
        v_Clob_Flag := 0;
        CONTINUE;      -- 进入下个字段处理
      END IF;
                        
      IF (Vi_Pre_Cols_Len > 4000) THEN
        IF (Vi_Sql_Val_Parts = 0) THEN
          v_Exestr := v_Exestr || v_Tmp;
        ELSE
          v_Exestr := v_Exestr || ', ' ||
                      v_Tmp;
        END IF;
        v_Tmp            := '';
        Vi_Sql_Val_Parts := Vi_Sql_Val_Parts + 1;
        Vi_Pre_Cols_Len  := c.Data_Length;
        Vi_Parts_Count   := 0;
      END IF;

      IF (Vi_Parts_Count < 1) THEN
        v_Links := '';
      ELSE
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Links := '||'', ''||';
      END IF;
      v_Tmp          := v_Tmp ||
                        v_Links ||
                        Vc_Sql_Part;
      Vi_Parts_Count := Vi_Parts_Count + 1;
    END LOOP;
    
    IF (Length(v_Tmp) > 0) THEN
      IF (v_Exestr IS NULL OR
         Length(TRIM(v_Exestr)) = 0) THEN
        v_Exestr := v_Tmp || ' from ' ||
                    Tabname ||
                    ' where ' ||
                    Pkvalue;
      ELSE
        v_Exestr := v_Exestr || ',' ||
                    v_Tmp || ' from ' ||
                    Tabname ||
                    ' where ' ||
                    Pkvalue;
      END IF;
      Vi_Sql_Val_Parts := Vi_Sql_Val_Parts + 1;
    ELSE
      v_Exestr := v_Exestr || ' from ' ||
                  Tabname || ' where ' ||
                  Pkvalue;
    END IF;

    v_Length := Length(v_Exestr);
    --DBMS_OUTPUT.PUT_LINE(V_LENGTH);
    CASE
      WHEN Vi_Sql_Val_Parts = 1 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1;
        v_Valstr := v_Into1;
      WHEN Vi_Sql_Val_Parts = 2 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2;
      WHEN Vi_Sql_Val_Parts = 3 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3;
      WHEN Vi_Sql_Val_Parts = 4 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4;

      WHEN Vi_Sql_Val_Parts = 5 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5;
      WHEN Vi_Sql_Val_Parts = 6 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5, v_Into6;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5 || ', ' ||
                    v_Into6;
      WHEN Vi_Sql_Val_Parts = 7 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5, v_Into6, v_Into7;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5 || ', ' ||
                    v_Into6 || ', ' ||
                    v_Into7;
      WHEN Vi_Sql_Val_Parts = 8 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5, v_Into6, v_Into7, v_Into8;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5 || ', ' ||
                    v_Into6 || ', ' ||
                    v_Into7 || ', ' ||
                    v_Into8;
      WHEN Vi_Sql_Val_Parts = 9 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5, v_Into6, v_Into7, v_Into8, v_Into9;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5 || ', ' ||
                    v_Into6 || ', ' ||
                    v_Into7 || ', ' ||
                    v_Into8 || ', ' ||
                    v_Into9;
      WHEN Vi_Sql_Val_Parts = 10 THEN
        EXECUTE IMMEDIATE v_Exestr
          INTO v_Into1, v_Into2, v_Into3, v_Into4, v_Into5, v_Into6, v_Into7, v_Into8, v_Into9, v_Into10;
        --每个列的值只见必须要使用', '分割，因为在sp_remove_null_value里面是用', '来分割每列之间的值的。
        --因为在列值当中会出现to_date函数里面的两个日期字符串之间的','
        --比如to_date('2006-07-07 00:00:00','yyyy-mm-dd hh24:mi:ss')
        --对于上述情况，如果还是使用','分割列值就会出错，郁闷
        v_Valstr := v_Into1 || ', ' ||
                    v_Into2 || ', ' ||
                    v_Into3 || ', ' ||
                    v_Into4 || ', ' ||
                    v_Into5 || ', ' ||
                    v_Into6 || ', ' ||
                    v_Into7 || ', ' ||
                    v_Into8 || ', ' ||
                    v_Into9 || ', ' ||
                    v_Into10;

    END CASE;
    
    -- 开始对blob字段进行处理，首先解析blob字段字符串
    IF (v_Blob_Names IS NOT NULL AND
      v_Blob_Num > 0 ) THEN
      v_Loop := 1;
      WHILE (v_Loop<=v_Blob_Num AND v_Blob_Names IS NOT NULL) LOOP
        -- 获取一个blob字段名
        v_Tmp_Name := NULL;
        IF (v_Loop = v_Blob_Num ) THEN
          v_Tmp_Name := v_Blob_Names;
        ELSE
          v_Loc := INSTR(v_Blob_Names, ',');
          v_Tmp_Name := SUBSTR(v_Blob_Names, 1, v_Loc-1);
          v_Blob_Names := SUBSTR(v_Blob_Names, v_Loc+1);
        END IF;
        
        IF (v_Tmp_Name IS NOT NULL ) THEN
           -- 将这个blob字段内容保存到本地目录
           SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Time_Flag from Dual;
           v_Tmp := 'BLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Time_Flag || '.RAW'; 
           om_dump_blob(v_Tmp_Name, Tabname, Pkvalue, v_Tmp);
           
           -- 判断RAW文件是否生成，进而判断此字段是否为空
           v_File_Loc := bfilename('SYN_DATA_EXPORT_SQL_DIR', v_Tmp);
           v_File_Exist := dbms_lob.fileexists(v_File_Loc)=1;
           
           -- 将这个blob字段名和值加入到字符串列表
           IF ( v_File_Exist ) THEN
             IF (v_Colstr IS NULL AND v_Valstr IS NULL) THEN
               v_Colstr := v_Tmp_Name;
               v_Valstr := 'LOB(''' || v_Tmp || ''')';
             ELSE
               v_Colstr := v_Colstr || ',' || v_Tmp_Name;
               v_Valstr := v_Valstr || ',' || 
                           'LOB(''' || v_Tmp || ''')';
             END IF;
           ELSE 
             IF (v_Colstr IS NULL AND v_Valstr IS NULL) THEN
               v_Colstr := v_Tmp_Name;
               v_Valstr := 'LOB(''empty_blob()' || ''')';
             ELSE
               v_Colstr := v_Colstr || ',' || v_Tmp_Name;
               v_Valstr := v_Valstr || ',' || 
                           'LOB(''empty_blob()' || ''')';
             END IF;             
           END IF;
        END IF;
        v_Loop := v_Loop + 1;
      END LOOP;
    END IF;
    
    -- 开始对clob字段进行处理
    IF (v_Clob_Names IS NOT NULL AND
      v_Clob_Num > 0 ) THEN
      v_Loop := 1;
      WHILE (v_Loop<=v_Clob_Num AND v_Clob_Names IS NOT NULL) LOOP
        -- 获取一个clob字段名
        v_Tmp_Name := NULL;
        IF (v_Loop = v_Clob_Num ) THEN
          v_Tmp_Name := v_Clob_Names;
        ELSE
          v_Loc := INSTR(v_Clob_Names, ',');
          v_Tmp_Name := SUBSTR(v_Clob_Names, 1, v_Loc-1);
          v_Clob_Names := SUBSTR(v_Clob_Names, v_Loc+1);
        END IF;
        
        IF (v_Tmp_Name IS NOT NULL ) THEN
           -- 将这个clob字段内容保存到本地目录
           SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into v_Time_Flag from Dual;
           v_Tmp := 'CLOB_' || SEQ_LOB_DATA_SYN.NEXTVAL || '_' || v_Time_Flag || '.TXT'; 
           om_dump_clob(v_Tmp_Name, Tabname, Pkvalue, v_Tmp);
           
           -- 判断RAW文件是否生成，进而判断此字段是否为空
           v_File_Loc := bfilename('SYN_DATA_EXPORT_SQL_DIR', v_Tmp);
           v_File_Exist := dbms_lob.fileexists(v_File_Loc)=1;
           
           -- 将这个clob字段名和值加入到字符串列表
           IF ( v_File_Exist ) THEN
             IF (v_Colstr IS NULL AND v_Valstr IS NULL) THEN
               v_Colstr := v_Tmp_Name;
               v_Valstr := 'LOB(''' || v_Tmp || ''')';
             ELSE
               v_Colstr := v_Colstr || ',' || v_Tmp_Name;
               v_Valstr := v_Valstr || ',' || 
                           'LOB(''' || v_Tmp || ''')';
             END IF;
           ELSE 
             IF (v_Colstr IS NULL AND v_Valstr IS NULL) THEN
               v_Colstr := v_Tmp_Name;
               v_Valstr := 'LOB(''empty_clob()' || ''')';
             ELSE
               v_Colstr := v_Colstr || ',' || v_Tmp_Name;
               v_Valstr := v_Valstr || ',' || 
                           'LOB(''empty_clob()' || ''')';
             END IF;
           END IF;
        END IF;
        v_Loop := v_Loop + 1;
      END LOOP;
    END IF;

    Sqlcolstr   := v_Colstr;
    Sqlcolvalue := v_Valstr;
  EXCEPTION
    WHEN No_Data_Found THEN
      NULL;
    WHEN OTHERS THEN
      Sqlcolstr   := NULL;
      Sqlcolvalue := NULL;
      v_Errtxt    := SQLERRM;
  END OM_Buildup_Inssql;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Updsql(Tabname     IN VARCHAR2,
                              Pkvalue     IN VARCHAR2,
                              Updatevalue IN VARCHAR2,
                              Updatesql   OUT VARCHAR2) IS
    v_Sqlstr     VARCHAR2(32767);
    v_Errtxt     VARCHAR2(200);
    
    v_Sql_Stat   VARCHAR2(32767);   -- SQL语句串
    v_Is_Lob     BOOLEAN := TRUE;   -- 是否存在BLOB字段标识，默认存在
    v_Lob_Block  VARCHAR2(100);     -- BLOB语句块 
    v_End_Loc    INTEGER :=0;       -- 截止位置
    v_Lob_Name   VARCHAR2(30);      -- BLOB文件名
    v_Tmp_Loc    INTEGER :=0;
    v_Field_Name VARCHAR2(30);      -- BLOB字段名
    v_Lob_Flag   CHARACTER;         -- BLOB/CLOB标识
  BEGIN
    -- 解析SQL语句中的BLOB字段
    v_Sql_Stat := Updatevalue;
    WHILE ( v_Is_Lob ) LOOP
      OM_Blob_Block(v_Sql_Stat, v_Lob_Block, v_End_Loc);
      
      IF ( v_Lob_Block IS NULL OR 
        v_End_Loc=0 ) THEN
        v_Is_Lob := FALSE;
      ELSE   -- 有BLOB字段
        v_Sql_Stat := substr(v_Sql_Stat, v_End_Loc+1);
        v_Is_Lob := TRUE;
        
        -- 将BLOB字段保存到本地
        IF ( v_Lob_Block IS NOT NULL ) THEN
          -- 获取字段名
          v_Tmp_Loc := instr(v_Lob_Block, '=', 1, 1);
          IF ( v_Tmp_Loc>0 ) THEN
            v_Field_Name := substr(v_Lob_Block, 1, v_Tmp_Loc-1);
          END IF;
          
          v_Tmp_Loc := instr(v_Lob_Block, '''', 1, 1);
          v_End_Loc := instr(v_Lob_Block, '''', 1, 2);
          -- 获取文件名
          IF ( v_Tmp_Loc>0 AND v_End_Loc>0 
            AND v_Field_Name IS NOT NULL) THEN
            v_Lob_Name := substr(v_Lob_Block, v_Tmp_Loc+1, v_End_Loc-v_Tmp_Loc-1);
            
            IF ( v_Lob_Name IS NOT NULL ) THEN
              v_Lob_Flag := substr(v_Lob_Name, 1, 1);
              
              IF ( v_Lob_Name='empty_blob()' OR 
                v_Lob_Name='EMPTY_BLOB()' OR 
                v_Lob_Name='empty_clob()' OR
                v_Lob_Name='EMPTY_BLOB()' ) THEN
                continue;
              END IF;
              
              IF ( v_Lob_Flag='B' ) THEN
                om_dump_blob(v_Field_Name, Tabname, Pkvalue, v_Lob_Name);  
              ELSIF ( v_Lob_Flag='C' ) THEN
                om_dump_clob(v_Field_Name, Tabname, Pkvalue, v_Lob_Name);
              END IF;
            END IF;
            
          END IF;
        END IF;
      END IF;
    END LOOP;
    
    v_Sqlstr  := 'UPDATE ' || Tabname ||
                 ' SET ';
    v_Sqlstr  := v_Sqlstr ||
                 Updatevalue;
    v_Sqlstr  := v_Sqlstr || ' WHERE ' ||
                 Pkvalue;
    Updatesql := v_Sqlstr;
  EXCEPTION
    WHEN No_Data_Found THEN
      NULL;
    WHEN OTHERS THEN
      v_Errtxt  := SQLERRM;
      Updatesql := NULL;
  END OM_Buildup_Updsql;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Buildup_Synsql IS
    Vc_Errtxt   VARCHAR2(200);
    Vc_Sql      VARCHAR2(32767);
    Vc_Colstr   VARCHAR2(32767);
    Vc_Valstr   VARCHAR2(32767);
    Vc_Filename VARCHAR2(128);
    Vc_Nameflag VARCHAR2(128);
    Vi_Filenum  INTEGER;
    Vi_Rowcount INTEGER := 0;

    Vi_Loop INTEGER := 0;
    Vi_File_Max_Rows   CONSTANT INTEGER := 2000;
    Vc_Sql_Start_Chars CONSTANT VARCHAR2(16) := '<';
    Vc_Sql_End_Chars   CONSTANT VARCHAR2(16) := '>';
    Sqlfile_Handle Utl_File.File_Type;
  BEGIN
    FOR c IN (SELECT *
                FROM OM_DATACHGINFO t
               ORDER BY t.Id) LOOP
      Vi_Rowcount := Vi_Rowcount + 1;
      IF (Vi_Rowcount = 1) THEN
        --第一行同步数据，生成同步文件名
        SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into Vc_Nameflag from Dual;
        Vc_Nameflag := 'branchplatform_syncdata_' || Vc_Nameflag;
        Vc_Filename    := Vc_Nameflag ||
                          '.sql.tmp';
        Sqlfile_Handle := Utl_File.Fopen('SYN_DATA_EXPORT_SQL_DIR',
                                         Vc_Filename,
                                         'w',
                                         32767);
      END IF;
      IF (Vi_Loop >= Vi_File_Max_Rows) THEN
        Utl_File.Fclose(Sqlfile_Handle);
        Utl_File.Frename('SYN_DATA_EXPORT_SQL_DIR',
                         Vc_Nameflag ||
                         '.sql.tmp',
                         'SYN_DATA_EXPORT_SQL_DIR',
                         Vc_Nameflag ||
                         '.sql',
                         TRUE);
        COMMIT;

        SELECT to_char(sysdate, 'YYYYMMDDHH24MISS') into Vc_Nameflag from Dual;
        Vc_Nameflag := 'branchplatform_syncdata_' || Vc_Nameflag;
        Vc_Filename    := Vc_Nameflag ||
                          '.sql.tmp';
        Sqlfile_Handle := Utl_File.Fopen('SYN_DATA_EXPORT_SQL_DIR',
                                         Vc_Filename,
                                         'w',
                                         32767);
        Vi_Loop        := 0;
      END IF;
      IF (c.Chgtype = 1) THEN
        --生成INSERT语句
        OM_Buildup_Inssql(c.Tabname,
                          c.Prikeyvalue,
                          Vc_Colstr,
                          Vc_Valstr);
        IF (Vc_Colstr IS NOT NULL AND
           Vc_Valstr IS NOT NULL) THEN

          --SP_REMOVE_NULL_VALUE(V_COLSTR, V_VALSTR);   --此存储过程在某些情况下会遇到问题
          IF (Vc_Colstr IS NOT NULL AND
             Vc_Valstr IS NOT NULL) THEN
            Vc_Sql := 'INSERT INTO ' ||
                      c.Tabname || '(' ||
                      Vc_Colstr ||
                      ') VALUES(' ||
                      Vc_Valstr || ')';
            -- 为每个sql语句添加一个序列号        
            SELECT SEQ_SUBSYS_DATA_SYN.NEXTVAL
                   INTO Vi_Filenum FROM Dual;
                                
            Vc_Sql := Vc_Sql_Start_Chars || 
                      Vi_Filenum || ':' || 
                      Vc_Sql ||
                      Vc_Sql_End_Chars;
            Utl_File.Put_Line(Sqlfile_Handle,
                              Vc_Sql);
            Vi_Loop := Vi_Loop + 1;
          END IF;
        END IF;

      ELSIF (c.Chgtype = 2) THEN
        --生成UPDATE语句
        OM_Buildup_Updsql(c.Tabname,
                          c.Prikeyvalue,
                          c.Updatevalue,
                          Vc_Sql);
        IF (Vc_Sql IS NOT NULL AND
           Length(TRIM(Vc_Sql)) > 0) THEN
            -- 为每个sql语句添加一个序列号        
            SELECT SEQ_SUBSYS_DATA_SYN.NEXTVAL
                   INTO Vi_Filenum FROM Dual;
                                
            Vc_Sql := Vc_Sql_Start_Chars || 
                      Vi_Filenum || ':' || 
                      Vc_Sql ||
                      Vc_Sql_End_Chars;
          Utl_File.Put_Line(Sqlfile_Handle,
                            Vc_Sql);
          Vi_Loop := Vi_Loop + 1;
        END IF;

      ELSE
        --生成DELETE语句
        OM_Buildup_Delsql(c.Tabname,
                          c.Prikeyvalue,
                          Vc_Sql);
            -- 为每个sql语句添加一个序列号        
            SELECT SEQ_SUBSYS_DATA_SYN.NEXTVAL
                   INTO Vi_Filenum FROM Dual;
                                
            Vc_Sql := Vc_Sql_Start_Chars || 
                      Vi_Filenum || ':' || 
                      Vc_Sql ||
                      Vc_Sql_End_Chars;
        Utl_File.Put_Line(Sqlfile_Handle,
                          Vc_Sql);
        Vi_Loop := Vi_Loop + 1;
      END IF;
      DELETE FROM OM_DATACHGINFO
       WHERE Id = c.Id;
    END LOOP;
    IF Utl_File.Is_Open(Sqlfile_Handle) THEN
      Utl_File.Fclose(Sqlfile_Handle);
      Utl_File.Frename('SYN_DATA_EXPORT_SQL_DIR',
                       Vc_Nameflag ||
                       '.sql.tmp',
                       'SYN_DATA_EXPORT_SQL_DIR',
                       Vc_Nameflag ||
                       '.sql',
                       TRUE);
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      IF Utl_File.Is_Open(Sqlfile_Handle) THEN
        Utl_File.Fclose(Sqlfile_Handle);
        Utl_File.Frename('SYN_DATA_EXPORT_SQL_DIR',
                         Vc_Nameflag ||
                         '.sql.tmp',
                         'SYN_DATA_EXPORT_SQL_DIR',
                         Vc_Nameflag ||
                         '.sql',
                         TRUE);
      END IF;
      Vc_Errtxt := SQLERRM;
      IF SQLCODE = 29285 THEN
        Vc_Errtxt := Vc_Errtxt ||
                     ',磁盘没有空间!';
      END IF;
      COMMIT;
  END OM_Buildup_Synsql;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Ins_Datachginfo(i_Tabname IN VARCHAR2,
                               i_Rowid   IN ROWID,
                               i_Pk_Val  IN VARCHAR2,
                               i_Type    IN INTEGER,
                               i_Upd_Val VARCHAR2) IS
  BEGIN
    INSERT INTO OM_DATACHGINFO
      (Id,
       Tabname,
       Recordid,
       Prikeyvalue,
       Chgtype,
       Updatevalue)
    VALUES
      (SEQ_OM_DATACHGINFO.NEXTVAL,
       i_Tabname,
       i_Rowid,
       i_Pk_Val,
       i_Type,
       i_Upd_Val);
  END OM_Ins_Datachginfo;

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Create_Syntable_Trg(Tabname IN VARCHAR2) IS
    v_Sqlstr    VARCHAR2(32767);
    v_Trgsql    VARCHAR2(32767);
    v_Newvalstr VARCHAR2(500) := 'V_PRIKEY_VALUE := ';
    v_Oldvalstr VARCHAR2(500) := 'V_PRIKEY_VALUE := ';
    v_Link1     VARCHAR2(50);
    v_Loop      INT := 0;

    v_Num       INT := 0;

    v_Tabname       VARCHAR2(128);
    v_Temp          VARCHAR2(30);
  BEGIN
    v_Tabname := Upper(Tabname);
    v_Temp    := v_Tabname;
    -- 首先判断表名是否超标(22个字符) [mc, 2012/06/26]
    v_Num     := LENGTH(v_Tabname);
    IF ( v_Num > 22 ) THEN
      v_Temp := SUBSTR(v_Tabname, v_Num-22+1, 22);

    END IF;

    v_Sqlstr  := 'create or replace trigger trg_' ||
                 v_Temp || '_syn ' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 'after insert or update or delete on ' ||
                 v_Tabname || Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 'for each row' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr || 'declare ' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 '   V_PRIKEY_VALUE OM_DATACHGINFO.prikeyvalue%TYPE; ' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 '   V_UPDATE_VALUE OM_DATACHGINFO.updatevalue%TYPE; ' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 '   v_upd_count number := 0; ' ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr ||
                 '   v_syn_flag  number := 0;'  ||
                 Chr(10);
    v_Sqlstr  := v_Sqlstr || 'begin ' ||
                 Chr(10);
    FOR Rec IN (SELECT c.Column_Name,
                       u.Data_Type
                  FROM User_Constraints  t,
                       User_Cons_Columns c,
                       User_Tab_Columns  u
                 WHERE t.Table_Name =
                       v_Tabname
                   AND u.Table_Name =
                       t.Table_Name
                   AND u.Column_Name =
                       c.Column_Name
                   AND t.Constraint_Name =
                       c.Constraint_Name
                   AND t.Table_Name =
                       c.Table_Name
                   AND t.Constraint_Type = 'P'
                 ORDER BY c.Position) LOOP
      v_Loop := v_Loop + 1;
      IF (v_Loop > 1) THEN
        v_Link1 := ' || '' AND ';
      ELSE
        v_Link1 := '''';
      END IF;
      CASE Rec.Data_Type
        WHEN 'VARCHAR2' THEN
          v_Newvalstr := v_Newvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         '=''''''|| :new.' ||
                         Rec.Column_Name ||
                         '||''''''''';
          v_Oldvalstr := v_Oldvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         '=''''''|| :old.' ||
                         Rec.Column_Name ||
                         '||''''''''';
        WHEN 'DATE' THEN
          v_Newvalstr := v_Newvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         '= TO_DATE(' ||
                         ''''''' ||
                                 to_char(:new.' ||
                         Rec.Column_Name || ',
                                         ''YYYY-MM-DD HH24:MI:SS'') || '''''', ''''YYYY-MM-DDHH24:MI:SS'''')''';
          v_Oldvalstr := v_Oldvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         ' =TO_DATE(' ||
                         '''''''||to_char(:old.' ||
                         Rec.Column_Name ||
                         ',''YYYY-MM-DD HH24:MI:SS'') || '''''',''''YYYY-MM-DD HH24:MI:SS'''')''';
        ELSE
          v_Newvalstr := v_Newvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         '=''|| :new.' ||
                         Rec.Column_Name;
          v_Oldvalstr := v_Oldvalstr ||
                         v_Link1 ||
                         Rec.Column_Name ||
                         '=''|| :old.' ||
                         Rec.Column_Name;
      END CASE;

    END LOOP;
    IF (v_Loop > 0) THEN
      v_Newvalstr := v_Newvalstr || ';';
      v_Oldvalstr := v_Oldvalstr || ';';
    ELSE
      --TRGSTR := '在指定的表里面没有找到主键列';
      RETURN;
    END IF;
    -- 增加group by对记录进行过滤 [zuow, 2012/07/09]
    v_Sqlstr := v_Sqlstr ||
                '  select SYNFLAG into v_syn_flag from BRANCH_PLATFORM_TABLE_SYN where UPPER(TABLENAME)= ''' || v_Tabname ||  '''GROUP BY SYNFLAG;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '  if (v_syn_flag = 1) then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '  if inserting then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '      ' ||
                v_Newvalstr || Chr(10);
    v_Sqlstr := v_Sqlstr || '    begin' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '       pkg_onemap.OM_Ins_Datachginfo(''' ||
                v_Tabname;
    v_Sqlstr := v_Sqlstr ||
                ''', :new.rowid, V_PRIKEY_VALUE, 1,''插入操作'');' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     exception' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     when others then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '        null;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     end ;' || Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '  elsif updating then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '      ' ||
                v_Oldvalstr || Chr(10);

    v_Loop := 0;
    FOR Rec IN (SELECT t.Column_Name,
                       t.Data_Type
                  FROM User_Tab_Columns t
                 WHERE t.Table_Name =
                       v_Tabname
                 ORDER BY t.Column_Id) LOOP
      v_Loop := v_Loop + 1;
      IF (v_Loop > 1) THEN
        v_Link1 := '||'',''||';
      ELSE
        v_Link1 := '';
      END IF;
      IF (Length(v_Sqlstr) > 30000) THEN
        v_Trgsql := v_Sqlstr;
        v_Sqlstr := '';
      END IF;

      v_Sqlstr := v_Sqlstr ||
                  '     if updating(''' ||
                  Rec.Column_Name ||
                  ''') then' || Chr(10);
      CASE Rec.Data_Type
        WHEN 'VARCHAR2' THEN
          v_Sqlstr := v_Sqlstr ||
                      '        pkg_onemap.OM_Update_Varchar2valstr(:new.' ||
                      Rec.Column_Name ||
                      ',:old.' ||
                      Rec.Column_Name ||
                      ',''' ||
                      Rec.Column_Name ||
                      ''',v_upd_count,v_update_value);' ||
                      Chr(10);
        WHEN 'DATE' THEN
          v_Sqlstr := v_Sqlstr ||
                      '        pkg_onemap.OM_Update_Datevalstr(:new.' ||
                      Rec.Column_Name ||
                      ',:old.' ||
                      Rec.Column_Name ||
                      ',''' ||
                      Rec.Column_Name ||
                      ''',v_upd_count,v_update_value);' ||
                      Chr(10);
        WHEN 'BLOB' THEN
          v_Sqlstr := v_Sqlstr ||
                      '        pkg_onemap.OM_Update_Blobvar(:new.' ||
                      Rec.Column_Name ||
                      ',''' ||
                      Rec.Column_Name ||
                      ''',v_upd_count,v_update_value, V_PRIKEY_VALUE' || 
                      ',''' || 
                      v_Tabname || 
                      ''');' ||
                      Chr(10);        
        WHEN 'CLOB' THEN
          v_Sqlstr := v_Sqlstr ||
                      '        pkg_onemap.OM_Update_Clobvar(:new.' ||
                      Rec.Column_Name ||
                      ',''' ||
                      Rec.Column_Name ||
                      ''',v_upd_count,v_update_value, V_PRIKEY_VALUE' || 
                      ',''' || 
                      v_Tabname || 
                      ''');' ||
                      Chr(10);                                              
        ELSE
          v_Sqlstr := v_Sqlstr ||
                      '        pkg_onemap.OM_Update_Numvalstr(:new.' ||
                      Rec.Column_Name ||
                      ',:old.' ||
                      Rec.Column_Name ||
                      ',''' ||
                      Rec.Column_Name ||
                      ''',v_upd_count,v_update_value);' ||
                      Chr(10);
      END CASE;
      v_Sqlstr := v_Sqlstr ||
                  '     end if;' ||
                  Chr(10);
    END LOOP;
    v_Sqlstr := v_Sqlstr ||
                '    if(v_update_value is not null) then ' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '    begin' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '       pkg_onemap.OM_Ins_Datachginfo(''' ||
                v_Tabname;
    v_Sqlstr := v_Sqlstr ||
                ''', :new.rowid, V_PRIKEY_VALUE, 2,v_update_value);' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     exception' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     when others then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '        null;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     end ;' || Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     end if;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '  else ' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '      ' ||
                v_Oldvalstr || Chr(10);
    v_Sqlstr := v_Sqlstr || '    begin' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '      pkg_onemap.OM_Ins_Datachginfo(''' ||
                v_Tabname;
    v_Sqlstr := v_Sqlstr ||
                ''', null, V_PRIKEY_VALUE, 3,''删除操作'');' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     exception' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     when others then' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '        null;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr ||
                '     end ;' || Chr(10);
    v_Sqlstr := v_Sqlstr || '  end if;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || '  end if;' ||
                Chr(10);
    v_Sqlstr := v_Sqlstr || 'end trg_' ||
                v_Temp || '_syn;';
    EXECUTE IMMEDIATE v_Trgsql || v_Sqlstr;
  END OM_Create_Syntable_Trg;
  
  /*----------------------------------------------------------------------------------*/
  PROCEDURE OM_Close_Triggle(Tabname IN VARCHAR2) is
    v_Tabname       VARCHAR2(128);
    v_Num           NUMBER;
    v_Sql_Stat      VARCHAR2(32767);
  BEGIN 
    v_Tabname := Upper(Tabname);
    
    -- 首先判断表名是否超标(22个字符) [mc, 2012/06/26]
    v_Num     := LENGTH(v_Tabname);
    IF ( v_Num > 22 ) THEN
      v_Tabname := SUBSTR(v_Tabname, v_Num-22+1, 22);
    END IF;    
    
    v_Tabname := 'TRG_' || v_Tabname || '_SYN';
    
    SELECT COUNT(*) INTO v_Num FROM user_triggers WHERE trigger_name=v_Tabname; 
    IF ( v_Num > 0 ) THEN
        v_Sql_Stat := 'ALTER TRIGGER ' || v_Tabname || ' DISABLE';
        EXECUTE IMMEDIATE v_Sql_Stat;

        v_Sql_Stat := 'drop trigger ' || v_Tabname;
        EXECUTE IMMEDIATE v_Sql_Stat;
    END IF;
  END OM_Close_Triggle;
  
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Dump_BLOB (i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2,
                          i_Blob_Name  IN VARCHAR2) IS
    l_file      UTL_FILE.FILE_TYPE;
    l_buffer    RAW(32767);
    l_amount    BINARY_INTEGER := 32767;
    l_pos       INTEGER := 1;
    l_blob      BLOB;
    l_blob_len  INTEGER; 
    
    v_fld_name  VARCHAR2(30);
    v_tab_name  VARCHAR2(30);
    v_pk_str    VARCHAR2(200);
    v_blob_name VARCHAR2(64);                         
  BEGIN
    -- 安全检查
    IF (i_Field_Name IS NULL OR 
      i_Table_Name IS NULL OR 
      i_Pk_Val IS NULL OR 
      i_Blob_Name IS NULL ) THEN
      return;
    END IF;
    
    v_fld_name := UPPER(i_Field_Name);
    v_tab_name := UPPER(i_Table_Name);
    v_pk_str   := i_Pk_Val;
    v_blob_name := i_Blob_Name;
    
    EXECUTE IMMEDIATE 'SELECT ' || v_fld_name || ' FROM ' || v_tab_name || ' WHERE ' || v_pk_str INTO l_blob;

    l_blob_len := DBMS_LOB.GETLENGTH(l_blob);
    -- 如果为空就退出
    IF ( l_blob_len <= 0 OR l_blob_len IS NULL) THEN
      RETURN;
    END IF;
    
    l_file := UTL_FILE.FOPEN('SYN_DATA_EXPORT_SQL_DIR', v_blob_name, 'wb', 32767);

    WHILE l_pos < l_blob_len LOOP
      DBMS_LOB.READ (l_blob, l_amount, l_pos, l_buffer);
      UTL_FILE.PUT_RAW(l_file, l_buffer, TRUE);
      l_pos := l_pos + l_amount;
    END LOOP;

    UTL_FILE.FCLOSE(l_file);
    EXCEPTION
      WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
          UTL_FILE.FCLOSE(l_file);
        END IF;
      RAISE; 
         
  END OM_Dump_BLOB;                          

  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Load_BLOB (i_Blob_Name  IN VARCHAR2,
                          i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2) IS
    v_fld_name  VARCHAR2(30);
    v_tab_name  VARCHAR2(30);
    v_pk_str    VARCHAR2(200);
    v_blob_name VARCHAR2(64);                           
                          
    src_file BFILE;
    dst_file BLOB;
    lgh_file BINARY_INTEGER;
    ii_temp  number;
  BEGIN
    -- 安全检查
    IF (i_Field_Name IS NULL OR 
      i_Table_Name IS NULL OR 
      i_Pk_Val IS NULL OR 
      i_Blob_Name IS NULL ) THEN
      return;
    END IF;
    
    v_fld_name := UPPER(i_Field_Name);
    v_tab_name := UPPER(i_Table_Name);
    v_pk_str   := i_Pk_Val;
    v_blob_name := i_Blob_Name;
    
    -- 打开文件        
    src_file := bfilename('SYN_DATA_EXPORT_SQL_DIR', v_blob_name);
    -- 将目标字段首先清空
    EXECUTE IMMEDIATE 'UPDATE ' || v_tab_name  || ' set ' || 
            v_fld_name || '=empty_blob() where ' || v_pk_str;
    
    EXECUTE IMMEDIATE 'SELECT ' || v_fld_name || ' FROM ' || 
            v_tab_name || ' WHERE ' || v_pk_str INTO dst_file;
                    
    dbms_lob.fileopen(src_file, dbms_lob.file_readonly);
    lgh_file := dbms_lob.getlength(src_file);
    dbms_lob.loadfromfile(dst_file, src_file, lgh_file);

--    UPDATE v_tab_name SET v_fld_name = dst_file where v_pk_str;
--    EXECUTE IMMEDIATE 'UPDATE ' || v_tab_name ||  
--          set  v_fld_name  =  dst_file || ' WHERE ' || v_pk_str;

    dbms_lob.fileclose(src_file);
    commit;    
  END OM_Load_BLOB;
  
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Dump_CLOB (i_Field_Name IN VARCHAR2, 
                          i_Table_Name IN VARCHAR2,
                          i_Pk_Val     IN VARCHAR2,
                          i_Clob_Name  IN VARCHAR2) IS
    l_file      UTL_FILE.FILE_TYPE;
    l_buffer    VARCHAR2(2000);
    l_amount    BINARY_INTEGER := 1024;
    l_pos       INTEGER := 1;
    l_clob      CLOB;
    l_clob_len  INTEGER; 
    
    v_fld_name  VARCHAR2(30);
    v_tab_name  VARCHAR2(30);
    v_pk_str    VARCHAR2(200);
    v_clob_name VARCHAR2(64);                         
  BEGIN
    -- 安全检查
    IF (i_Field_Name IS NULL OR 
      i_Table_Name IS NULL OR 
      i_Pk_Val IS NULL OR 
      i_Clob_Name IS NULL ) THEN
      return;
    END IF;
    
    v_fld_name := UPPER(i_Field_Name);
    v_tab_name := UPPER(i_Table_Name);
    v_pk_str   := i_Pk_Val;
    v_clob_name := i_Clob_Name;
    
    EXECUTE IMMEDIATE 'SELECT ' || v_fld_name || ' FROM ' || v_tab_name || ' WHERE ' || v_pk_str INTO l_clob;

    l_clob_len := DBMS_LOB.GETLENGTH(l_clob);
    -- 如果为空就退出
    IF ( l_clob_len <= 0 OR l_clob_len IS NULL ) THEN
      RETURN;
    END IF;    
    l_file := UTL_FILE.FOPEN('SYN_DATA_EXPORT_SQL_DIR', v_clob_name, 'w', 32767);

    WHILE l_pos < l_clob_len LOOP
      DBMS_LOB.READ (l_clob, l_amount, l_pos, l_buffer);
      UTL_FILE.PUT(l_file, l_buffer);
      UTL_FILE.FFLUSH(l_file);
      l_pos := l_pos + l_amount;
    END LOOP;

    UTL_FILE.FCLOSE(l_file);
    EXCEPTION
      WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
          UTL_FILE.FCLOSE(l_file);
        END IF;
      RAISE; 
         
  END OM_Dump_CLOB;  
  
  /*-------------------------------------------------------------------------------------*/
  PROCEDURE OM_Blob_Block(i_Sql_Stat   IN  VARCHAR2,
                          o_Blob_Block OUT VARCHAR2,
                          o_End_Loc    OUT INTEGER) IS
    v_Sql_Stat            VARCHAR2(32767);
    v_Sub_Str             VARCHAR2(32767);
    
    v_Loc1                INTEGER :=0;
    v_Loc2                INTEGER :=0;
    v_Loc3                INTEGER :=1;
  BEGIN
    v_Sql_Stat := i_Sql_Stat;
    o_End_Loc := 0;
    IF( v_Sql_Stat IS NULL ) THEN
      RETURN;
    END IF;
    
    -- 查找是否包含BLOB字段
    SELECT regexp_instr(v_Sql_Stat, 'LOB(*)', 1, 1) INTO v_Loc1 FROM dual;
    
    IF ( v_Loc1>0 ) THEN
      -- 查找左边','    
      WHILE (v_Loc3>0 ) LOOP
        IF( v_Loc2 >= v_Loc1 ) THEN
          NULL;
        END IF;
        
        SELECT instr(substr(v_Sql_Stat, v_Loc2+1, v_Loc1-v_Loc2+1), ',', 1, 1) INTO v_Loc3 FROM dual;
        v_Loc2 := v_Loc2 + v_Loc3;
      END LOOP;
      
      -- 查找右边','
      SELECT instr(substr(v_Sql_Stat, v_Loc1), ',', 1, 1) INTO v_Loc3 FROM dual;
      IF ( v_Loc3=0 ) THEN  -- 没有其它字段
        v_Loc3 := LENGTH(v_Sql_Stat) + 1;
      ELSE     -- 还有其它字段
        v_Loc3 := v_Loc1 + v_Loc3 -1;
      END IF;
      
      IF ( v_Loc3 > v_Loc2 ) THEN
        o_Blob_Block := substr(v_Sql_Stat, v_Loc2+1, v_Loc3-v_Loc2-1);
        dbms_output.put_line(o_Blob_Block);
      END IF;
      
      o_End_Loc := v_Loc3;
    ELSE 
      RETURN;
    END IF;
  
  END OM_Blob_Block;  
                            
END Pkg_Onemap;
/

prompt
prompt Grant Create Trigger to geoshare_platform
prompt =========================================
prompt
grant create trigger to geoshare_platform;

prompt
prompt Create Trigger trg_BRANCH_PLATFORM_TABLE_SYN
prompt ============================================
prompt
create or replace trigger trg_BRANCH_PLATFORM_TABLE_SYN 
after insert on BRANCH_PLATFORM_TABLE_SYN
for each row
declare 
    v_Prikeystr VARCHAR2(32767);
    v_Link1     VARCHAR2(50);
    v_Loop      INT := 0;
    
    v_Tablename   VARCHAR2(128);
    
    v_Sql_Stat    VARCHAR2(32767);
    PRAGMA AUTONOMOUS_TRANSACTION;    
begin 
  v_Tablename := Upper(:new.TABLENAME);
  
  -- 首先查询是否已有此表记录
  v_Sql_Stat := 'select count(*) from BRANCH_PLATFORM_TABLE_SYN where TABLENAME=''' || v_Tablename || '''';
  EXECUTE IMMEDIATE v_Sql_Stat into v_Loop;
  if ( v_Loop >1 ) THEN
    return;
  END IF;
  
  v_Loop := 0;
  
  -- 将视图中的记录逐一取出，并解析，然后将解析结果插入到OM_DATACHGINFO表中
  v_Sql_Stat := 'declare' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '  v_Prikeystr VARCHAR2(300);' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '  v_Rowid VARCHAR2(64);' || 
                Chr(10);  
  v_Sql_Stat := v_Sql_Stat || 
                'begin' || 
                Chr(10);                                                
  v_Sql_Stat :=  v_Sql_Stat || 
                 '  FOR Rec IN (SELECT * FROM ' || v_Tablename || ') LOOP' || 
                 Chr(10);
  -- 获取主键字符串
  FOR Fld IN (SELECT c.Column_Name,
                     u.Data_Type 
              FROM User_Constraints t,
                   User_Cons_Columns c,
                   User_Tab_Columns u 
              WHERE t.Table_Name = v_Tablename 
              AND u.Table_Name = t.Table_Name 
              AND u.Column_Name = c.Column_Name 
              AND t.Constraint_Name = c.Constraint_Name 
              AND t.Table_Name = c.Table_Name 
              AND t.Constraint_Type = 'P'
              ORDER BY c.Position) LOOP
     v_Loop := v_Loop + 1;
     IF (v_Loop > 1 ) THEN
       v_Link1 := ' || '' AND ';
     ELSE 
       v_Link1 := '''';
     END IF;
      
     CASE Fld.Data_Type
     WHEN 'VARCHAR2'THEN 
       v_Prikeystr := v_Prikeystr || v_Link1 || Fld.Column_Name || '= ''''''|| Rec.' || Fld.Column_Name || '||''''''''';
     WHEN 'DATE' THEN 
       v_Prikeystr := v_Prikeystr || v_Link1 || Fld.Column_Name || '= TO_DATE(' || ''''''' || to_char(Rec.' || Fld.Column_Name ||',''YYYY-MM-DD HH24:MI:SS'') || '''''', ''''YYYY-MM-DD HH24:MI:SS'''')''';
     ELSE 
       v_Prikeystr := v_Prikeystr || v_Link1 || Fld.Column_Name || '= ''|| Rec.'|| Fld.Column_Name ;
     END CASE;
  END LOOP;
    
  IF (v_Loop <= 0) THEN 
    return;
  END IF;

  v_Sql_Stat := v_Sql_Stat || 
                '    v_Prikeystr := ' || v_Prikeystr || ';' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '    EXECUTE IMMEDIATE ''' ||  'SELECT ROWID FROM ' || v_Tablename || ' WHERE ''|| ' || ' v_Prikeystr INTO v_Rowid;' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '    IF v_Rowid is NULL THEN ' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '      NULL;' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '    END IF;' || 
                Chr(10);                                                                                           
  v_Sql_Stat := v_Sql_Stat || 
                '    pkg_onemap.OM_Ins_Datachginfo(''' || v_Tablename || ''', v_Rowid, v_Prikeystr , 1, ''' || '插入操作''' || ');' || 
                Chr(10);
  v_Sql_Stat := v_Sql_Stat || 
                '  END LOOP;' || 
                Chr(10);                                  
  v_Sql_Stat := v_Sql_Stat || 
                'END;' ||
                Chr(10);
                  
--  insert into TMPDEBUG values(rawtohex(v_Sql_Stat));
  
  EXECUTE IMMEDIATE v_Sql_Stat;
  pkg_onemap.OM_Create_Syntable_Trg(v_Tablename);

end trg_GEOSHARE_TABLE_SYN_bak;
/

spool off
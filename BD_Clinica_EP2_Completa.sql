-- =====================================================================
-- BDY1103 - TALLER DE BASE DE DATOS
-- EVALUACION PARCIAL 2 - CASO: SISTEMA DE GESTION DE UNA CLINICA
-- SCRIPT COMPLETO DE ENTREGA (EP2)
-- Estudiante: Sebastian Antipan
--
-- Este script se ejecuta solo, desde cero. Incluye la base de datos de la
-- evaluacion anterior (12 tablas y la carga de 120 pacientes) para que la
-- entrega no dependa de otro archivo, y luego crea todos los objetos de
-- la EP2.
--
-- ORDEN DE EJECUCION (todo en un solo run, de arriba hacia abajo):
--   0. Limpieza total del esquema
--   1. Creacion de las 12 tablas
--   2. Datos base (catalogos)
--   3. Generacion masiva de 120 pacientes y datos relacionados
--   4. Verificacion de volumenes cargados
--   5. Base de datos: ejemplos 1 a 9 (RECORD, VARRAY, cursores,
--      excepciones, procedimiento, funcion, package y trigger de fila)
--   6. Objetos de la EP2: tabla bitacora_citas, procedimiento y funcion
--      sin parametros, package publico/privado y trigger de sentencia
--   7. Verificacion final de volumenes
--
-- IMPORTANTE:
--   * Ejecutar como SCRIPT COMPLETO (F5 en SQL Developer) o con
--     @ruta/BD_Clinica_EP2_Completa.sql en SQL*Plus.
--   * No requiere haber ejecutado nada antes: limpia y vuelve a crear
--     el esquema completo.
--   * La carga masiva usa DBMS_RANDOM.SEED(2026) para que SIEMPRE se
--     generen exactamente los mismos datos en cualquier equipo.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =====================================================================
-- 0. LIMPIEZA TOTAL DEL ESQUEMA
--    Se eliminan las tablas en orden inverso a las dependencias
--    (hijas primero). Si una tabla no existe, se ignora y se sigue.
-- =====================================================================

DECLARE
    TYPE t_tablas IS VARRAY(12) OF VARCHAR2(40);
    v_tablas t_tablas := t_tablas(
        'RECETA_DETALLE','RECETA','TRATAMIENTO','DIAGNOSTICO',
        'HISTORIAL_MEDICO','CITA','MEDICO_ESPECIALIDAD','MEDICAMENTO',
        'CONSULTORIO','PACIENTE','MEDICO','ESPECIALIDAD'
    );
BEGIN
    FOR i IN 1..v_tablas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_tablas(i) || ' PURGE';
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Limpieza de esquema finalizada.');
END;
/

-- =====================================================================
-- 1. CREACION DE TABLAS (12 tablas)
--    Orden pensado para respetar las FK (padres antes que hijos).
-- =====================================================================

CREATE TABLE especialidad (
    id_especialidad     NUMBER(4)       CONSTRAINT pk_especialidad PRIMARY KEY,
    nombre_especialidad VARCHAR2(60)    NOT NULL,
    descripcion         VARCHAR2(200)
);

CREATE TABLE medico (
    id_medico    NUMBER(6)       CONSTRAINT pk_medico PRIMARY KEY,
    rut          VARCHAR2(12)    NOT NULL,
    nombre       VARCHAR2(60)    NOT NULL,
    apellido     VARCHAR2(60)    NOT NULL,
    telefono     VARCHAR2(20),
    email        VARCHAR2(100),
    fecha_ingreso DATE          DEFAULT SYSDATE,
    CONSTRAINT uq_medico_rut UNIQUE (rut)
);

CREATE TABLE medico_especialidad (
    id_medico       NUMBER(6)   NOT NULL,
    id_especialidad NUMBER(4)   NOT NULL,
    CONSTRAINT pk_medico_especialidad PRIMARY KEY (id_medico, id_especialidad),
    CONSTRAINT fk_medesp_medico FOREIGN KEY (id_medico)
        REFERENCES medico (id_medico),
    CONSTRAINT fk_medesp_especialidad FOREIGN KEY (id_especialidad)
        REFERENCES especialidad (id_especialidad)
);

CREATE TABLE consultorio (
    id_consultorio  NUMBER(4)   CONSTRAINT pk_consultorio PRIMARY KEY,
    nombre          VARCHAR2(40) NOT NULL,
    piso            NUMBER(2),
    ubicacion       VARCHAR2(100)
);

CREATE TABLE paciente (
    id_paciente      NUMBER(8)      CONSTRAINT pk_paciente PRIMARY KEY,
    rut              VARCHAR2(12)   NOT NULL,
    nombre           VARCHAR2(60)   NOT NULL,
    apellido         VARCHAR2(60)   NOT NULL,
    fecha_nacimiento DATE           NOT NULL,
    sexo             CHAR(1)        CHECK (sexo IN ('M','F')),
    telefono         VARCHAR2(20),
    direccion        VARCHAR2(150),
    email            VARCHAR2(100),
    fecha_registro   DATE           DEFAULT SYSDATE,
    CONSTRAINT uq_paciente_rut UNIQUE (rut)
);

CREATE TABLE cita (
    id_cita         NUMBER(10)   CONSTRAINT pk_cita PRIMARY KEY,
    id_paciente     NUMBER(8)    NOT NULL,
    id_medico       NUMBER(6)    NOT NULL,
    id_consultorio  NUMBER(4)    NOT NULL,
    fecha_cita      DATE         NOT NULL,
    hora_cita       VARCHAR2(5)  NOT NULL,
    estado          VARCHAR2(20) DEFAULT 'PROGRAMADA'
                     CHECK (estado IN ('PROGRAMADA','ATENDIDA','CANCELADA','NO_ASISTIO')),
    CONSTRAINT fk_cita_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_cita_medico FOREIGN KEY (id_medico)
        REFERENCES medico (id_medico),
    CONSTRAINT fk_cita_consultorio FOREIGN KEY (id_consultorio)
        REFERENCES consultorio (id_consultorio)
);

CREATE TABLE diagnostico (
    id_diagnostico     NUMBER(10)   CONSTRAINT pk_diagnostico PRIMARY KEY,
    id_cita            NUMBER(10)   NOT NULL,
    codigo_cie         VARCHAR2(10),
    descripcion        VARCHAR2(300) NOT NULL,
    fecha_diagnostico  DATE         DEFAULT SYSDATE,
    CONSTRAINT fk_diag_cita FOREIGN KEY (id_cita)
        REFERENCES cita (id_cita)
);

CREATE TABLE historial_medico (
    id_historial     NUMBER(10)   CONSTRAINT pk_historial PRIMARY KEY,
    id_paciente      NUMBER(8)    NOT NULL,
    fecha_registro   DATE         DEFAULT SYSDATE,
    observaciones    VARCHAR2(500),
    CONSTRAINT fk_hist_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente)
);

CREATE TABLE tratamiento (
    id_tratamiento   NUMBER(10)   CONSTRAINT pk_tratamiento PRIMARY KEY,
    id_diagnostico   NUMBER(10)   NOT NULL,
    descripcion      VARCHAR2(300) NOT NULL,
    fecha_inicio     DATE         DEFAULT SYSDATE,
    fecha_fin        DATE,
    CONSTRAINT fk_trat_diagnostico FOREIGN KEY (id_diagnostico)
        REFERENCES diagnostico (id_diagnostico)
);

CREATE TABLE medicamento (
    id_medicamento  NUMBER(6)    CONSTRAINT pk_medicamento PRIMARY KEY,
    nombre          VARCHAR2(100) NOT NULL,
    descripcion     VARCHAR2(200),
    stock           NUMBER(6)    DEFAULT 0,
    precio          NUMBER(10,2) DEFAULT 0
);

CREATE TABLE receta (
    id_receta    NUMBER(10)   CONSTRAINT pk_receta PRIMARY KEY,
    id_cita      NUMBER(10)   NOT NULL,
    id_medico    NUMBER(6)    NOT NULL,
    fecha_receta DATE         DEFAULT SYSDATE,
    CONSTRAINT fk_receta_cita FOREIGN KEY (id_cita)
        REFERENCES cita (id_cita),
    CONSTRAINT fk_receta_medico FOREIGN KEY (id_medico)
        REFERENCES medico (id_medico)
);

CREATE TABLE receta_detalle (
    id_receta       NUMBER(10)   NOT NULL,
    id_medicamento  NUMBER(6)    NOT NULL,
    dosis           VARCHAR2(60),
    frecuencia      VARCHAR2(60),
    duracion_dias   NUMBER(4),
    CONSTRAINT pk_receta_detalle PRIMARY KEY (id_receta, id_medicamento),
    CONSTRAINT fk_recdet_receta FOREIGN KEY (id_receta)
        REFERENCES receta (id_receta),
    CONSTRAINT fk_recdet_medicamento FOREIGN KEY (id_medicamento)
        REFERENCES medicamento (id_medicamento)
);

COMMIT;

-- =====================================================================
-- 2. DATOS BASE (catalogos pequenos)
--    especialidad, medico, medico_especialidad, consultorio, medicamento
-- =====================================================================

INSERT INTO especialidad VALUES (1,  'Medicina General', 'Atencion primaria y control general');
INSERT INTO especialidad VALUES (2,  'Pediatria', 'Atencion de ninos y adolescentes');
INSERT INTO especialidad VALUES (3,  'Cardiologia', 'Enfermedades del corazon');
INSERT INTO especialidad VALUES (4,  'Dermatologia', 'Enfermedades de la piel');
INSERT INTO especialidad VALUES (5,  'Traumatologia', 'Lesiones oseas y musculares');
INSERT INTO especialidad VALUES (6,  'Ginecologia', 'Salud reproductiva femenina');
INSERT INTO especialidad VALUES (7,  'Oftalmologia', 'Enfermedades de la vista');
INSERT INTO especialidad VALUES (8,  'Otorrinolaringologia', 'Oido, nariz y garganta');
INSERT INTO especialidad VALUES (9,  'Psiquiatria', 'Salud mental');
INSERT INTO especialidad VALUES (10, 'Endocrinologia', 'Enfermedades hormonales y metabolicas');

INSERT INTO medico VALUES (1,  '11111111-1', 'Andrea',   'Soto',      '+56911111111', 'a.soto@clinica.cl',    DATE '2018-03-01');
INSERT INTO medico VALUES (2,  '22222222-2', 'Bastian',  'Rojas',     '+56922222222', 'b.rojas@clinica.cl',   DATE '2019-05-15');
INSERT INTO medico VALUES (3,  '33333333-3', 'Carla',    'Fuentes',   '+56933333333', 'c.fuentes@clinica.cl', DATE '2017-11-20');
INSERT INTO medico VALUES (4,  '44444444-4', 'Diego',    'Munoz',     '+56944444444', 'd.munoz@clinica.cl',   DATE '2020-01-10');
INSERT INTO medico VALUES (5,  '55555555-5', 'Elena',    'Vargas',    '+56955555555', 'e.vargas@clinica.cl',  DATE '2016-07-07');
INSERT INTO medico VALUES (6,  '66666666-6', 'Francisco','Herrera',   '+56966666666', 'f.herrera@clinica.cl', DATE '2021-02-25');
INSERT INTO medico VALUES (7,  '77777777-7', 'Gabriela', 'Contreras', '+56977777777', 'g.contreras@clinica.cl', DATE '2015-09-09');
INSERT INTO medico VALUES (8,  '88888888-8', 'Hugo',     'Silva',     '+56988888888', 'h.silva@clinica.cl',   DATE '2019-10-30');
INSERT INTO medico VALUES (9,  '99999999-9', 'Ignacia',  'Pizarro',   '+56999999999', 'i.pizarro@clinica.cl', DATE '2022-04-18');
INSERT INTO medico VALUES (10, '10101010-1', 'Javier',   'Cortes',    '+56910101010', 'j.cortes@clinica.cl',  DATE '2018-12-12');

INSERT INTO medico_especialidad VALUES (1, 1);
INSERT INTO medico_especialidad VALUES (2, 2);
INSERT INTO medico_especialidad VALUES (3, 3);
INSERT INTO medico_especialidad VALUES (4, 4);
INSERT INTO medico_especialidad VALUES (5, 5);
INSERT INTO medico_especialidad VALUES (6, 6);
INSERT INTO medico_especialidad VALUES (7, 7);
INSERT INTO medico_especialidad VALUES (8, 8);
INSERT INTO medico_especialidad VALUES (9, 9);
INSERT INTO medico_especialidad VALUES (10, 10);
INSERT INTO medico_especialidad VALUES (1, 10);
INSERT INTO medico_especialidad VALUES (3, 1);

INSERT INTO consultorio VALUES (1, 'Consultorio 101', 1, 'Ala Norte');
INSERT INTO consultorio VALUES (2, 'Consultorio 102', 1, 'Ala Norte');
INSERT INTO consultorio VALUES (3, 'Consultorio 201', 2, 'Ala Sur');
INSERT INTO consultorio VALUES (4, 'Consultorio 202', 2, 'Ala Sur');
INSERT INTO consultorio VALUES (5, 'Consultorio 301', 3, 'Ala Poniente');
INSERT INTO consultorio VALUES (6, 'Consultorio 302', 3, 'Ala Poniente');

INSERT INTO medicamento VALUES (1,  'Paracetamol 500mg',   'Analgesico y antipiretico',       500, 1200);
INSERT INTO medicamento VALUES (2,  'Ibuprofeno 400mg',    'Antiinflamatorio no esteroidal',  400, 1800);
INSERT INTO medicamento VALUES (3,  'Amoxicilina 500mg',   'Antibiotico',                     300, 3500);
INSERT INTO medicamento VALUES (4,  'Loratadina 10mg',     'Antihistaminico',                 250, 2200);
INSERT INTO medicamento VALUES (5,  'Omeprazol 20mg',      'Protector gastrico',              350, 2900);
INSERT INTO medicamento VALUES (6,  'Losartan 50mg',       'Antihipertensivo',                200, 4200);
INSERT INTO medicamento VALUES (7,  'Metformina 850mg',    'Antidiabetico',                   220, 3100);
INSERT INTO medicamento VALUES (8,  'Salbutamol Inhalador','Broncodilatador',                 150, 5600);
INSERT INTO medicamento VALUES (9,  'Diclofenaco 50mg',    'Antiinflamatorio',                280, 1500);
INSERT INTO medicamento VALUES (10, 'Cetirizina 10mg',     'Antihistaminico',                 260, 2000);
INSERT INTO medicamento VALUES (11, 'Vitamina C 1g',       'Suplemento vitaminico',           400, 2500);
INSERT INTO medicamento VALUES (12, 'Ranitidina 150mg',    'Protector gastrico',              180, 1900);

COMMIT;

-- =====================================================================
-- 3. GENERACION MASIVA DE DATOS
--    Genera 120 pacientes (> 100 exigidos por el requerimiento) y, en
--    cascada, citas, diagnosticos, historial medico, tratamientos,
--    recetas y detalle de receta.
--
--    Usa VARRAY, cursores y ciclos anidados (coherente con lo pedido
--    en la base de datos: RECORD, VARRAY, cursores complejos,
--    loops anidados y manejo de excepciones).
--
--    DBMS_RANDOM.SEED fija la semilla para que la carga sea
--    REPRODUCIBLE: en cualquier equipo se generan los mismos datos.
-- =====================================================================

DECLARE

    -- VARRAY con nombres y apellidos para generar pacientes variados
    TYPE t_nombres   IS VARRAY(20) OF VARCHAR2(30);
    TYPE t_apellidos IS VARRAY(20) OF VARCHAR2(30);

    v_nombres_m t_nombres := t_nombres(
        'Mateo','Benjamin','Vicente','Agustin','Martin','Joaquin','Lucas',
        'Tomas','Sebastian','Gaspar','Cristobal','Ignacio','Maximiliano',
        'Diego','Felipe','Renato','Emilio','Pedro','Julian','Nicolas');

    v_nombres_f t_nombres := t_nombres(
        'Isidora','Emilia','Sofia','Antonia','Amanda','Josefa','Martina',
        'Trinidad','Florencia','Catalina','Valentina','Maite','Agustina',
        'Constanza','Javiera','Camila','Fernanda','Rosario','Paz','Ambar');

    v_apellidos t_apellidos := t_apellidos(
        'Gonzalez','Munoz','Rojas','Diaz','Perez','Soto','Contreras',
        'Silva','Martinez','Sepulveda','Morales','Rodriguez','Lopez',
        'Fuentes','Hernandez','Torres','Araya','Flores','Espinoza','Reyes');

    v_id_paciente     NUMBER := 1;
    v_id_cita         NUMBER := 1;
    v_id_diagnostico  NUMBER := 1;
    v_id_historial    NUMBER := 1;
    v_id_tratamiento  NUMBER := 1;
    v_id_receta       NUMBER := 1;

    v_sexo         CHAR(1);
    v_nombre       VARCHAR2(30);
    v_apellido     VARCHAR2(30);
    v_rut          VARCHAR2(12);
    v_fecha_nac    DATE;
    v_num_citas    NUMBER;
    v_id_medico    NUMBER;
    v_id_consult   NUMBER;
    v_fecha_cita   DATE;
    v_num_recetas  NUMBER;
    v_num_meds     NUMBER;
    v_id_med       NUMBER;

    -- Excepcion definida por el usuario: valida que el rango de
    -- edades generado sea coherente (entre 0 y 100 anios)
    e_edad_invalida EXCEPTION;

BEGIN

    -- Fija la semilla: los mismos datos en cada ejecucion
    DBMS_RANDOM.SEED(2026);

    -- ==================================================================
    -- CICLO PRINCIPAL: 120 pacientes (ciclo anidado con generacion de
    -- citas/diagnosticos/tratamientos/recetas para cada paciente)
    -- ==================================================================
    FOR i IN 1..120 LOOP

        v_sexo := CASE WHEN MOD(i, 2) = 0 THEN 'M' ELSE 'F' END;

        IF v_sexo = 'M' THEN
            v_nombre := v_nombres_m(MOD(i, v_nombres_m.COUNT) + 1);
        ELSE
            v_nombre := v_nombres_f(MOD(i, v_nombres_f.COUNT) + 1);
        END IF;

        v_apellido  := v_apellidos(MOD(i * 3, v_apellidos.COUNT) + 1);
        v_rut       := LPAD(TO_CHAR(20000000 + i), 8, '0') || '-' || TO_CHAR(MOD(i, 10));
        v_fecha_nac := ADD_MONTHS(DATE '2024-01-01', -1 * (TRUNC(DBMS_RANDOM.VALUE(1, 900))));

        -- Validacion con excepcion definida por el usuario
        IF (TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_nac) / 12)) > 100 THEN
            RAISE e_edad_invalida;
        END IF;

        INSERT INTO paciente (
            id_paciente, rut, nombre, apellido, fecha_nacimiento,
            sexo, telefono, direccion, email, fecha_registro
        ) VALUES (
            v_id_paciente, v_rut, v_nombre, v_apellido, v_fecha_nac,
            v_sexo,
            '+569' || LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(10000000,99999999))), 8, '0'),
            'Calle ' || v_apellido || ' ' || TO_CHAR(100 + i),
            LOWER(v_nombre) || '.' || LOWER(v_apellido) || i || '@correo.cl',
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 700))
        );

        -- Historial medico (1 por paciente)
        INSERT INTO historial_medico (id_historial, id_paciente, fecha_registro, observaciones)
        VALUES (
            v_id_historial, v_id_paciente, SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1,700)),
            'Historial creado automaticamente para ' || v_nombre || ' ' || v_apellido
        );
        v_id_historial := v_id_historial + 1;

        -- Cada paciente tiene entre 1 y 3 citas (ciclo anidado interno)
        v_num_citas := TRUNC(DBMS_RANDOM.VALUE(1, 4));

        FOR j IN 1..v_num_citas LOOP

            v_id_medico  := TRUNC(DBMS_RANDOM.VALUE(1, 11));   -- 1..10
            v_id_consult := TRUNC(DBMS_RANDOM.VALUE(1, 7));    -- 1..6
            v_fecha_cita := SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 365));

            INSERT INTO cita (
                id_cita, id_paciente, id_medico, id_consultorio,
                fecha_cita, hora_cita, estado
            ) VALUES (
                v_id_cita, v_id_paciente, v_id_medico, v_id_consult,
                v_fecha_cita,
                LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(8,19))),2,'0') || ':' ||
                    CASE WHEN MOD(j,2) = 0 THEN '30' ELSE '00' END,
                'ATENDIDA'
            );

            -- Diagnostico asociado a la cita
            INSERT INTO diagnostico (
                id_diagnostico, id_cita, codigo_cie, descripcion, fecha_diagnostico
            ) VALUES (
                v_id_diagnostico, v_id_cita,
                'CIE-' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(100,999))),
                'Diagnostico de control rutinario para ' || v_nombre,
                v_fecha_cita
            );

            -- Tratamiento asociado al diagnostico (no todos los diagnosticos
            -- requieren tratamiento; se genera para ~70% de los casos)
            IF MOD(j + i, 10) < 7 THEN
                INSERT INTO tratamiento (
                    id_tratamiento, id_diagnostico, descripcion,
                    fecha_inicio, fecha_fin
                ) VALUES (
                    v_id_tratamiento, v_id_diagnostico,
                    'Tratamiento indicado segun diagnostico ' || v_id_diagnostico,
                    v_fecha_cita, v_fecha_cita + 10
                );
                v_id_tratamiento := v_id_tratamiento + 1;
            END IF;

            -- Receta asociada a la cita (no todas las citas generan receta)
            IF MOD(j + i, 3) = 0 THEN
                INSERT INTO receta (id_receta, id_cita, id_medico, fecha_receta)
                VALUES (v_id_receta, v_id_cita, v_id_medico, v_fecha_cita);

                v_num_meds := TRUNC(DBMS_RANDOM.VALUE(1, 3)); -- 1 o 2 medicamentos

                FOR k IN 1..v_num_meds LOOP
                    v_id_med := TRUNC(DBMS_RANDOM.VALUE(1, 13)); -- 1..12
                    BEGIN
                        INSERT INTO receta_detalle (
                            id_receta, id_medicamento, dosis, frecuencia, duracion_dias
                        ) VALUES (
                            v_id_receta, v_id_med,
                            '1 comprimido', 'Cada 8 horas',
                            TRUNC(DBMS_RANDOM.VALUE(3, 15))
                        );
                    EXCEPTION
                        -- Si por combinacion aleatoria se repite el mismo
                        -- medicamento en la misma receta (viola PK compuesta),
                        -- se ignora ese duplicado y se continua el ciclo.
                        WHEN DUP_VAL_ON_INDEX THEN
                            NULL;
                    END;
                END LOOP;

                v_id_receta := v_id_receta + 1;
            END IF;

            v_id_diagnostico := v_id_diagnostico + 1;
            v_id_cita        := v_id_cita + 1;

        END LOOP; -- fin ciclo citas por paciente

        v_id_paciente := v_id_paciente + 1;

    END LOOP; -- fin ciclo pacientes

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Carga completa: ' || (v_id_paciente - 1) || ' pacientes generados.');
    DBMS_OUTPUT.PUT_LINE('Citas generadas: ' || (v_id_cita - 1));
    DBMS_OUTPUT.PUT_LINE('Diagnosticos generados: ' || (v_id_diagnostico - 1));
    DBMS_OUTPUT.PUT_LINE('Tratamientos generados: ' || (v_id_tratamiento - 1));
    DBMS_OUTPUT.PUT_LINE('Recetas generadas: ' || (v_id_receta - 1));

EXCEPTION
    WHEN e_edad_invalida THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: se genero una edad fuera de rango (0-100 anios). Proceso revertido.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);

END;
/

-- =====================================================================
-- 4. VERIFICACION DE VOLUMEN DE DATOS CARGADOS
-- =====================================================================
SELECT 'especialidad' tabla, COUNT(*) registros FROM especialidad
UNION ALL
SELECT 'medico', COUNT(*) FROM medico
UNION ALL
SELECT 'medico_especialidad', COUNT(*) FROM medico_especialidad
UNION ALL
SELECT 'consultorio', COUNT(*) FROM consultorio
UNION ALL
SELECT 'paciente', COUNT(*) FROM paciente
UNION ALL
SELECT 'cita', COUNT(*) FROM cita
UNION ALL
SELECT 'diagnostico', COUNT(*) FROM diagnostico
UNION ALL
SELECT 'historial_medico', COUNT(*) FROM historial_medico
UNION ALL
SELECT 'tratamiento', COUNT(*) FROM tratamiento
UNION ALL
SELECT 'medicamento', COUNT(*) FROM medicamento
UNION ALL
SELECT 'receta', COUNT(*) FROM receta
UNION ALL
SELECT 'receta_detalle', COUNT(*) FROM receta_detalle
ORDER BY 1;

-- =====================================================================
-- 5. EJEMPLOS DE LOS CONTENIDOS EXIGIDOS POR LA PAUTA
-- =====================================================================

-- =====================================================================
-- EJEMPLO 1: TIPO DE DATO RECORD
-- =====================================================================
-- El RECORD agrupa varios datos relacionados del paciente en una sola
-- estructura (en vez de usar variables sueltas por cada dato). Con un
-- SELECT INTO se llenan todos los campos de una vez y se accede a cada
-- uno con notacion de punto (v_paciente.edad).
-- =====================================================================

DECLARE
    TYPE t_paciente_rec IS RECORD (
        id_paciente      paciente.id_paciente%TYPE,
        nombre_completo  VARCHAR2(120),
        edad             NUMBER,
        sexo             paciente.sexo%TYPE
    );

    v_paciente t_paciente_rec;

BEGIN
    SELECT
        id_paciente,
        nombre || ' ' || apellido,
        TRUNC(MONTHS_BETWEEN(SYSDATE, fecha_nacimiento) / 12),
        sexo
    INTO
        v_paciente.id_paciente,
        v_paciente.nombre_completo,
        v_paciente.edad,
        v_paciente.sexo
    FROM paciente
    WHERE id_paciente = 1;

    DBMS_OUTPUT.PUT_LINE('--- Ficha de paciente (usando RECORD) ---');
    DBMS_OUTPUT.PUT_LINE('ID        : ' || v_paciente.id_paciente);
    DBMS_OUTPUT.PUT_LINE('Nombre    : ' || v_paciente.nombre_completo);
    DBMS_OUTPUT.PUT_LINE('Edad      : ' || v_paciente.edad || ' anios');
    DBMS_OUTPUT.PUT_LINE('Sexo      : ' || v_paciente.sexo);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No existe un paciente con ese id.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/

-- =====================================================================
-- EJEMPLO 2: TIPO DE DATO VARRAY
-- =====================================================================
-- El VARRAY es una lista ordenada con un maximo de posiciones. Aqui se
-- guardan nombres de especialidades (VARRAY(10)) y se recorren con un
-- bucle usando .COUNT para saber cuantos elementos hay cargados.
-- =====================================================================

DECLARE
    TYPE t_especialidades IS VARRAY(10) OF VARCHAR2(60);

    v_lista_especialidades t_especialidades;

BEGIN
    v_lista_especialidades := t_especialidades(
        'Medicina General',
        'Pediatria',
        'Cardiologia',
        'Dermatologia',
        'Traumatologia'
    );

    DBMS_OUTPUT.PUT_LINE('--- Especialidades cargadas en el VARRAY ---');

    FOR i IN 1..v_lista_especialidades.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(i || '. ' || v_lista_especialidades(i));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total de especialidades en el VARRAY: '
        || v_lista_especialidades.COUNT);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/

-- =====================================================================
-- EJEMPLO 3: CURSOR EXPLICITO COMPLEJO CON PARAMETROS + LOOPS ANIDADOS
-- =====================================================================
-- Cursor EXTERNO (sin parametros): recorres pacientes.
-- Cursor INTERNO (con parametro): recibe el id del paciente actual y
-- trae sus citas con JOIN a medico. El bucle anidado abre el cursor
-- interno con un valor distinto por cada paciente (mas de un Loop en
-- forma simultanea, tal como exige la pauta).
-- =====================================================================

DECLARE

    CURSOR c_pacientes IS
        SELECT id_paciente, nombre, apellido
        FROM paciente
        WHERE sexo = 'F'
        ORDER BY id_paciente
        FETCH FIRST 5 ROWS ONLY;

    CURSOR c_citas_paciente (p_id_paciente NUMBER) IS
        SELECT c.id_cita, c.fecha_cita, c.estado,
               m.nombre || ' ' || m.apellido AS medico_tratante
        FROM cita c
        JOIN medico m ON m.id_medico = c.id_medico
        WHERE c.id_paciente = p_id_paciente
        ORDER BY c.fecha_cita;

    v_total_citas NUMBER;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Reporte de pacientes y sus citas ===');

    FOR reg_paciente IN c_pacientes LOOP
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Paciente #' || reg_paciente.id_paciente
            || ' - ' || reg_paciente.nombre || ' ' || reg_paciente.apellido);

        v_total_citas := 0;

        FOR reg_cita IN c_citas_paciente(reg_paciente.id_paciente) LOOP
            DBMS_OUTPUT.PUT_LINE('   Cita #' || reg_cita.id_cita
                || ' | ' || TO_CHAR(reg_cita.fecha_cita, 'DD-MM-YYYY')
                || ' | Estado: ' || reg_cita.estado
                || ' | Medico: ' || reg_cita.medico_tratante);
            v_total_citas := v_total_citas + 1;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('   -> Total de citas de este paciente: ' || v_total_citas);
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/

-- =====================================================================
-- EJEMPLO 4: EXCEPCIONES PREDEFINIDAS DE ORACLE
-- =====================================================================
-- NO_DATA_FOUND: el SELECT INTO no encuentra ninguna fila.
-- TOO_MANY_ROWS : el SELECT INTO encuentra mas de una fila.
-- No es necesario declararlas ni lanzarlas: Oracle las levanta solo.
-- =====================================================================

DECLARE
    v_nombre_medico  medico.nombre%TYPE;
    v_id_buscado     medico.id_medico%TYPE := 9999;
    v_cantidad_citas NUMBER;

BEGIN
    -- CASO A: forzamos NO_DATA_FOUND (el medico 9999 no existe)
    BEGIN
        SELECT nombre
        INTO v_nombre_medico
        FROM medico
        WHERE id_medico = v_id_buscado;

        DBMS_OUTPUT.PUT_LINE('Medico encontrado: ' || v_nombre_medico);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('CASO A: No existe un medico con id '
                || v_id_buscado || ' (excepcion NO_DATA_FOUND capturada).');
    END;

    -- CASO B: forzamos TOO_MANY_ROWS (la consulta devuelve varias filas)
    BEGIN
        SELECT COUNT(*)
        INTO v_cantidad_citas
        FROM cita
        WHERE id_paciente IN (
            SELECT id_paciente FROM paciente WHERE ROWNUM <= 3
        )
        GROUP BY id_paciente;

        DBMS_OUTPUT.PUT_LINE('Cantidad de citas: ' || v_cantidad_citas);
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('CASO B: La consulta devolvio mas de una fila '
                || '(excepcion TOO_MANY_ROWS capturada). '
                || 'Se debe usar un cursor o ajustar el filtro.');
    END;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/

-- =====================================================================
-- EJEMPLO 5: EXCEPCION DEFINIDA POR EL USUARIO
-- =====================================================================
-- Regla de negocio propia: no se puede registrar una receta si la
-- cantidad pedida supera el stock. Como Oracle no conoce esta regla,
-- se declara la excepcion con EXCEPTION y se lanza con RAISE.
-- =====================================================================

DECLARE
    e_stock_insuficiente EXCEPTION;

    v_id_medicamento   medicamento.id_medicamento%TYPE := 3; -- Amoxicilina
    v_cantidad_pedida  NUMBER := 10000;
    v_stock_actual     medicamento.stock%TYPE;
    v_nombre_medic     medicamento.nombre%TYPE;

BEGIN
    SELECT stock, nombre
    INTO v_stock_actual, v_nombre_medic
    FROM medicamento
    WHERE id_medicamento = v_id_medicamento;

    DBMS_OUTPUT.PUT_LINE('Medicamento: ' || v_nombre_medic);
    DBMS_OUTPUT.PUT_LINE('Stock disponible: ' || v_stock_actual);
    DBMS_OUTPUT.PUT_LINE('Cantidad solicitada: ' || v_cantidad_pedida);

    IF v_cantidad_pedida > v_stock_actual THEN
        RAISE e_stock_insuficiente;
    END IF;

    UPDATE medicamento
    SET stock = stock - v_cantidad_pedida
    WHERE id_medicamento = v_id_medicamento;

    DBMS_OUTPUT.PUT_LINE('Receta registrada correctamente. Stock actualizado.');
    COMMIT;

EXCEPTION
    WHEN e_stock_insuficiente THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Stock insuficiente para "' || v_nombre_medic
            || '". Disponible: ' || v_stock_actual
            || ', solicitado: ' || v_cantidad_pedida || '.');
        ROLLBACK;
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No existe el medicamento indicado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =====================================================================
-- EJEMPLO 6: PROCEDIMIENTO ALMACENADO
-- =====================================================================
-- se registra una nueva cita validando previamente que el paciente y el
-- medico existan. Queda guardado en la BD y se puede invocar las veces
-- necesarias sin reescribir la logica.
-- =====================================================================

CREATE OR REPLACE PROCEDURE sp_registrar_cita (
    p_id_paciente     IN paciente.id_paciente%TYPE,
    p_id_medico       IN medico.id_medico%TYPE,
    p_id_consultorio  IN consultorio.id_consultorio%TYPE,
    p_fecha_cita      IN DATE,
    p_hora_cita       IN VARCHAR2
) IS

    v_existe_paciente NUMBER;
    v_existe_medico   NUMBER;
    v_nuevo_id_cita   NUMBER;

BEGIN
    SELECT COUNT(*) INTO v_existe_paciente
    FROM paciente WHERE id_paciente = p_id_paciente;

    SELECT COUNT(*) INTO v_existe_medico
    FROM medico WHERE id_medico = p_id_medico;

    IF v_existe_paciente = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No se puede registrar la cita: el paciente '
            || p_id_paciente || ' no existe.');
        RETURN;
    END IF;

    IF v_existe_medico = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No se puede registrar la cita: el medico '
            || p_id_medico || ' no existe.');
        RETURN;
    END IF;

    SELECT NVL(MAX(id_cita), 0) + 1 INTO v_nuevo_id_cita FROM cita;

    INSERT INTO cita (
        id_cita, id_paciente, id_medico, id_consultorio,
        fecha_cita, hora_cita, estado
    ) VALUES (
        v_nuevo_id_cita, p_id_paciente, p_id_medico, p_id_consultorio,
        p_fecha_cita, p_hora_cita, 'PROGRAMADA'
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Cita #' || v_nuevo_id_cita || ' registrada correctamente '
        || 'para el paciente ' || p_id_paciente
        || ' con el medico ' || p_id_medico || '.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar la cita: ' || SQLERRM);
END sp_registrar_cita;
/

-- PRUEBA DEL PROCEDIMIENTO
BEGIN
    sp_registrar_cita(
        p_id_paciente    => 1,
        p_id_medico      => 2,
        p_id_consultorio => 3,
        p_fecha_cita     => SYSDATE + 7,
        p_hora_cita      => '10:30'
    );
END;
/

-- =====================================================================
-- EJEMPLO 7: FUNCION ALMACENADA
-- =====================================================================
-- Devuelve un valor con RETURN (la edad de un paciente). Por eso se
-- puede usar dentro de un SELECT, algo que un procedimiento no puede.
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_calcular_edad (
    p_id_paciente IN paciente.id_paciente%TYPE
) RETURN NUMBER IS

    v_fecha_nac  paciente.fecha_nacimiento%TYPE;

BEGIN
    SELECT fecha_nacimiento
    INTO v_fecha_nac
    FROM paciente
    WHERE id_paciente = p_id_paciente;

    RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_nac) / 12);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END fn_calcular_edad;
/

-- PRUEBA 1: la funcion dentro de un bloque PL/SQL
DECLARE
    v_edad_paciente NUMBER;
BEGIN
    v_edad_paciente := fn_calcular_edad(1);
    DBMS_OUTPUT.PUT_LINE('La edad del paciente 1 es: ' || v_edad_paciente || ' anios.');
END;
/

-- PRUEBA 2: la funcion directamente dentro de un SELECT
SELECT id_paciente,
       nombre || ' ' || apellido AS nombre_completo,
       fn_calcular_edad(id_paciente) AS edad
FROM paciente
WHERE ROWNUM <= 10
ORDER BY id_paciente;

-- =====================================================================
-- EJEMPLO 8: PACKAGE (especificacion + cuerpo)
-- =====================================================================
-- Agrupa la funcion de edad y el procedimiento de citas bajo un mismo
-- nombre logico (pkg_gestion_pacientes). La spec declara QUE existe;
-- el body implementa COMO funciona cada elemento.
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_gestion_pacientes IS

    FUNCTION fn_calcular_edad_pkg (
        p_id_paciente IN paciente.id_paciente%TYPE
    ) RETURN NUMBER;

    PROCEDURE sp_registrar_cita_pkg (
        p_id_paciente     IN paciente.id_paciente%TYPE,
        p_id_medico       IN medico.id_medico%TYPE,
        p_id_consultorio  IN consultorio.id_consultorio%TYPE,
        p_fecha_cita      IN DATE,
        p_hora_cita       IN VARCHAR2
    );

END pkg_gestion_pacientes;
/

CREATE OR REPLACE PACKAGE BODY pkg_gestion_pacientes IS

    FUNCTION fn_calcular_edad_pkg (
        p_id_paciente IN paciente.id_paciente%TYPE
    ) RETURN NUMBER IS
        v_fecha_nac paciente.fecha_nacimiento%TYPE;
    BEGIN
        SELECT fecha_nacimiento INTO v_fecha_nac
        FROM paciente WHERE id_paciente = p_id_paciente;

        RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_nac) / 12);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END fn_calcular_edad_pkg;

    PROCEDURE sp_registrar_cita_pkg (
        p_id_paciente     IN paciente.id_paciente%TYPE,
        p_id_medico       IN medico.id_medico%TYPE,
        p_id_consultorio  IN consultorio.id_consultorio%TYPE,
        p_fecha_cita      IN DATE,
        p_hora_cita       IN VARCHAR2
    ) IS
        v_nuevo_id_cita NUMBER;
    BEGIN
        SELECT NVL(MAX(id_cita), 0) + 1 INTO v_nuevo_id_cita FROM cita;

        INSERT INTO cita (
            id_cita, id_paciente, id_medico, id_consultorio,
            fecha_cita, hora_cita, estado
        ) VALUES (
            v_nuevo_id_cita, p_id_paciente, p_id_medico, p_id_consultorio,
            p_fecha_cita, p_hora_cita, 'PROGRAMADA'
        );

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Cita #' || v_nuevo_id_cita
            || ' registrada mediante el package.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error al registrar la cita: ' || SQLERRM);
    END sp_registrar_cita_pkg;

END pkg_gestion_pacientes;
/

-- PRUEBA DEL PACKAGE (patron paquete.elemento)
DECLARE
    v_edad NUMBER;
BEGIN
    v_edad := pkg_gestion_pacientes.fn_calcular_edad_pkg(2);
    DBMS_OUTPUT.PUT_LINE('Edad del paciente 2 (via package): ' || v_edad || ' anios.');

    pkg_gestion_pacientes.sp_registrar_cita_pkg(
        p_id_paciente    => 2,
        p_id_medico      => 4,
        p_id_consultorio => 1,
        p_fecha_cita     => SYSDATE + 3,
        p_hora_cita      => '09:00'
    );
END;
/

-- =====================================================================
-- EJEMPLO 9: TRIGGER
-- =====================================================================
-- Cada vez que se inserta un registro en RECETA_DETALLE, el trigger
-- descuenta automaticamente 1 unidad del stock usando la referencia
-- :NEW, sin que el programador deba acordarse de hacerlo manualmente.
-- =====================================================================

CREATE OR REPLACE TRIGGER trg_descontar_stock
AFTER INSERT ON receta_detalle
FOR EACH ROW
DECLARE
    v_stock_actual medicamento.stock%TYPE;
BEGIN
    SELECT stock INTO v_stock_actual
    FROM medicamento
    WHERE id_medicamento = :NEW.id_medicamento;

    IF v_stock_actual > 0 THEN
        UPDATE medicamento
        SET stock = stock - 1
        WHERE id_medicamento = :NEW.id_medicamento;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Aviso: el medicamento ' || :NEW.id_medicamento
            || ' ya no tiene stock disponible.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en trigger trg_descontar_stock: ' || SQLERRM);
END trg_descontar_stock;
/

-- PRUEBA DEL TRIGGER
SELECT id_medicamento, nombre, stock FROM medicamento WHERE id_medicamento = 1;

DELETE FROM receta_detalle WHERE id_receta = 1 AND id_medicamento = 1;
COMMIT;

INSERT INTO receta_detalle (id_receta, id_medicamento, dosis, frecuencia, duracion_dias)
VALUES (1, 1, '1 comprimido', 'Cada 8 horas', 5);

COMMIT;

SELECT id_medicamento, nombre, stock FROM medicamento WHERE id_medicamento = 1;

-- =====================================================================
-- EVALUACION PARCIAL 2
-- =====================================================================

-- =====================================================================
-- BDY1103 - TALLER DE BASE DE DATOS
-- CASO DE ANALISIS: SISTEMA DE GESTION DE UNA CLINICA
-- EVALUACION PARCIAL 2: PROCEDIMIENTOS, FUNCIONES, PACKAGES Y TRIGGERS
-- Estudiante: Sebastian Antipan
-- =====================================================================
-- Esta seccion se ejecuta sobre la base que el mismo script crea mas
-- arriba. Agrega la tabla de apoyo y los objetos PL/SQL nuevos de la
-- EP2, siguiendo la numeracion de ejemplos de la base de datos. Si se
-- ejecuta este script completo, no hay que ejecutar nada aparte.
--
-- CONTENIDO:
-- 6. Tabla de apoyo bitacora_citas
-- 7. EJEMPLO 10: PROCEDIMIENTO SIN PARAMETROS (sp_resumen_clinica)
-- 8. EJEMPLO 11: FUNCION SIN PARAMETROS (fn_total_pacientes)
-- 9. EJEMPLO 12: PACKAGE CON PARTE PUBLICA Y PRIVADA (pkg_reportes_clinica)
-- 10. EJEMPLO 13: TRIGGER A NIVEL DE SENTENCIA (trg_bitacora_cita)
-- 11. VERIFICACION FINAL DE VOLUMENES
-- =====================================================================



-- =====================================================================
-- 6. TABLA DE APOYO: BITACORA_CITAS
-- =====================================================================
-- Requerida por el trigger a nivel de sentencia (EJEMPLO 13). Guarda
-- un solo registro cada vez que se ejecuta una insercion sobre la
-- tabla CITA, de modo que quede una bitacora de accesos a los datos.
-- =====================================================================

-- Se elimina la tabla de apoyo si ya existe, para permitir una nueva
-- ejecucion completa del script.
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE bitacora_citas PURGE';
EXCEPTION
    WHEN OTHERS THEN
        NULL;   -- si no existe, se ignora
END;
/

CREATE TABLE bitacora_citas (
    id_bitacora   NUMBER(6)   CONSTRAINT pk_bitacora_citas PRIMARY KEY,
    fecha_evento  DATE        DEFAULT SYSDATE,
    usuario_bd    VARCHAR2(60),
    detalle       VARCHAR2(200)
);


-- =====================================================================
-- EJEMPLO 10: PROCEDIMIENTO ALMACENADO SIN PARAMETROS
-- =====================================================================
-- Un procedimiento SIN parametros no recibe datos de entrada: trabaja
-- con TODO el conjunto de informacion de la clinica. Aqui genera el
-- resumen general (procesamiento masivo sobre los 120 pacientes, los
-- medicos, las citas y el stock de medicamentos).
-- =====================================================================

CREATE OR REPLACE PROCEDURE sp_resumen_clinica IS

    v_total_pacientes    NUMBER;
    v_total_medicos      NUMBER;
    v_total_citas        NUMBER;
    v_stock_medicamentos NUMBER;

BEGIN
    SELECT COUNT(*) INTO v_total_pacientes FROM paciente;
    SELECT COUNT(*) INTO v_total_medicos   FROM medico;
    SELECT COUNT(*) INTO v_total_citas     FROM cita;
    SELECT NVL(SUM(stock), 0) INTO v_stock_medicamentos FROM medicamento;

    DBMS_OUTPUT.PUT_LINE('===== RESUMEN GENERAL DE LA CLINICA =====');
    DBMS_OUTPUT.PUT_LINE('Pacientes registrados    : ' || v_total_pacientes);
    DBMS_OUTPUT.PUT_LINE('Medicos registrados      : ' || v_total_medicos);
    DBMS_OUTPUT.PUT_LINE('Citas registradas        : ' || v_total_citas);
    DBMS_OUTPUT.PUT_LINE('Unidades de medicamentos : ' || v_stock_medicamentos);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END sp_resumen_clinica;
/

-- Validacion 1: invocacion del procedimiento desde una sentencia SQL.
-- La salida se obtiene con DBMS_OUTPUT.
CALL sp_resumen_clinica();

-- Validacion 2: invocacion del procedimiento desde un bloque PL/SQL.
DECLARE
    v_mensaje VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Ejecutando el reporte general automaticamente...');
    sp_resumen_clinica;
    v_mensaje := 'Reporte generado el ' || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI');
    DBMS_OUTPUT.PUT_LINE(v_mensaje);
END;
/


-- =====================================================================
-- EJEMPLO 11: FUNCION ALMACENADA SIN PARAMETROS
-- =====================================================================
-- La funcion SIN parametros tampoco recibe entrada, pero SI devuelve
-- un valor con RETURN (al contrario del procedimiento). Por eso puede
-- usarse directamente en un SELECT.
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_total_pacientes RETURN NUMBER IS

    v_total NUMBER;

BEGIN
    SELECT COUNT(*) INTO v_total FROM paciente;
    RETURN v_total;

EXCEPTION
    WHEN OTHERS THEN
        RETURN -1;
END fn_total_pacientes;
/

-- Validacion 1: uso de la funcion en una sentencia SQL.
SELECT fn_total_pacientes AS total_pacientes_de_la_clinica FROM dual;

-- Validacion 2: uso de la funcion en un bloque PL/SQL.
DECLARE
    v_total NUMBER;
BEGIN
    v_total := fn_total_pacientes;
    DBMS_OUTPUT.PUT_LINE('La clinica atiende hoy a ' || v_total
        || ' pacientes.');
END;
/

-- Validacion 3: uso de fn_calcular_edad en un bloque PL/SQL.
DECLARE
    v_edad NUMBER;
BEGIN
    v_edad := fn_calcular_edad(1);
    DBMS_OUTPUT.PUT_LINE('La edad del paciente 1 es ' || v_edad
        || ' anios (calculada con fn_calcular_edad).');
END;
/


-- =====================================================================
-- EJEMPLO 12: PACKAGE CON PARTE PUBLICA Y PARTE PRIVADA
-- =====================================================================
-- Un package tiene dos bloques:
--   * ESPECIFICACION (spec): es lo PUBLICO. Declara los elementos que
--     cualquier programa o sentencia SQL puede invocar.
--   * CUERPO (body): implementa la logica y puede incluir elementos
--     PRIVADOS (variables y funciones que aparecen solo aqui, no en la
--     spec). Esos elementos privados son de uso interno del package y
--     nadie de afuera puede llamarlos.
--
-- En este package:
--   PUBLICO : fn_citas_medico (cuenta las citas atendidas de un medico)
--             sp_mostrar_usos (muestra el contador interno)
--   PRIVADO : v_usos (variable interna del package)
--             fn_medico_existe (funcion de apoyo para validar datos)
-- =====================================================================

-- ---------- ESPECIFICACION (lo que se ve desde afuera) ---------------
CREATE OR REPLACE PACKAGE pkg_reportes_clinica IS

    FUNCTION fn_citas_medico (
        p_id_medico IN medico.id_medico%TYPE
    ) RETURN NUMBER;

    PROCEDURE sp_mostrar_usos;

END pkg_reportes_clinica;
/

-- ---------- CUERPO (lo que se ve y lo que queda privado) --------------
CREATE OR REPLACE PACKAGE BODY pkg_reportes_clinica IS

    -- PARTE PRIVADA 1: variable interna del package. Vive mientras
    -- dure la sesion de trabajo y solo el propio package la puede
    -- leer o modificar.
    v_usos NUMBER := 0;

    -- PARTE PRIVADA 2: funcion de apoyo. NO esta declarada en la spec,
    -- por lo que no puede llamarse desde afuera: solo sirve dentro del
    -- body para validar que el medico exista.
    FUNCTION fn_medico_existe (
        p_id_medico IN medico.id_medico%TYPE
    ) RETURN NUMBER IS
        v_cuenta NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_cuenta
        FROM medico
        WHERE id_medico = p_id_medico;

        RETURN v_cuenta;
    END fn_medico_existe;

    -- PARTE PUBLICA: implementa la funcion declarada en la spec.
    FUNCTION fn_citas_medico (
        p_id_medico IN medico.id_medico%TYPE
    ) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        v_usos := v_usos + 1;

        IF fn_medico_existe(p_id_medico) = 0 THEN
            RETURN -1;   -- medico inexistente (regla interna)
        END IF;

        SELECT COUNT(*) INTO v_total
        FROM cita
        WHERE id_medico = p_id_medico;

        RETURN v_total;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN -2;
    END fn_citas_medico;

    -- PARTE PUBLICA: expone el contador privado (unico acceso externo
    -- a la variable interna).
    PROCEDURE sp_mostrar_usos IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Este package se ha usado ' || v_usos
            || ' veces en esta sesion.');
    END sp_mostrar_usos;

END pkg_reportes_clinica;
/

-- Validacion 1: uso de la funcion publica del package en una sentencia
-- SQL sobre todos los medicos. Devuelve la cantidad de citas de cada uno.
SELECT m.id_medico AS medico,
       m.nombre || ' ' || m.apellido AS nombre_medico,
       pkg_reportes_clinica.fn_citas_medico(m.id_medico) AS citas_atendidas
FROM medico m
ORDER BY m.id_medico;

-- Validacion 2: medico inexistente. La parte privada valida los datos
-- y devuelve -1.
SELECT pkg_reportes_clinica.fn_citas_medico(9999) AS medico_inexistente
FROM dual;

-- Validacion 3: uso del package desde un bloque PL/SQL, consultando el
-- contador interno por medio del procedimiento publico.
DECLARE
    v_citas_medico_2 NUMBER;
BEGIN
    v_citas_medico_2 := pkg_reportes_clinica.fn_citas_medico(2);
    DBMS_OUTPUT.PUT_LINE('El medico 2 tiene ' || v_citas_medico_2
        || ' citas registradas.');
    pkg_reportes_clinica.sp_mostrar_usos;
END;
/

-- Validacion 4: intento de acceso a fn_medico_existe desde fuera del
-- package. Oracle rechaza la llamada con PLS-00231 u ORA-00904; el
-- error se controla con SQL dinamico para continuar con el script.
DECLARE
    v_resultado NUMBER;
BEGIN
    EXECUTE IMMEDIATE
        'SELECT pkg_reportes_clinica.fn_medico_existe(1) FROM dual'
        INTO v_resultado;
    DBMS_OUTPUT.PUT_LINE('Resultado inesperado: ' || v_resultado);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error esperado al llamar la parte privada: '
            || SQLERRM);
END;
/


-- =====================================================================
-- EJEMPLO 13: TRIGGER A NIVEL DE SENTENCIA
-- =====================================================================
-- El trigger de fila (EJEMPLO 9) era "FOR EACH ROW": se dispara
-- una vez POR CADA FILA insertada. Este trigger NO tiene FOR EACH ROW,
-- por lo que se dispara UNA SOLA VEZ por cada sentencia INSERT que se
-- ejecute, aunque esa sentencia inserte 1 fila o 500 filas a la vez.
-- Cada disparo queda registrado en la bitacora de la seccion 6.
-- =====================================================================

CREATE OR REPLACE TRIGGER trg_bitacora_cita
AFTER INSERT ON cita
DECLARE
    v_nuevo_id NUMBER;
BEGIN
    SELECT NVL(MAX(id_bitacora), 0) + 1 INTO v_nuevo_id FROM bitacora_citas;

    INSERT INTO bitacora_citas (
        id_bitacora, usuario_bd, detalle
    ) VALUES (
        v_nuevo_id,
        USER,
        'Se ejecuto una insercion en la tabla CITA '
        || '(nivel de sentencia)'
    );

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en trigger trg_bitacora_cita: ' || SQLERRM);
END trg_bitacora_cita;
/

-- Validacion: insercion de 3 citas en UNA SOLA sentencia. El trigger
-- de sentencia se dispara una sola vez, por lo que la bitacora registra
-- 1 fila y no 3. Asi se diferencia del trigger de fila.
DECLARE
    v_base NUMBER;
BEGIN
    SELECT NVL(MAX(id_cita), 0) INTO v_base FROM cita;

    INSERT INTO cita (
        id_cita, id_paciente, id_medico, id_consultorio,
        fecha_cita, hora_cita, estado
    )
    SELECT v_base + ROWNUM,
           id_paciente,
           1,                       -- medico 1
           1,                       -- consultorio 1
           SYSDATE + 7,             -- control dentro de una semana
           '09:00',
           'PROGRAMADA'
    FROM paciente
    WHERE ROWNUM <= 3;

    DBMS_OUTPUT.PUT_LINE('La sentencia inserto ' || SQL%ROWCOUNT
        || ' citas de una sola vez.');
    COMMIT;
END;
/

-- Consulta de la bitacora. Se espera un unico registro nuevo,
-- correspondiente a las 3 citas insertadas en una sola sentencia.
SELECT id_bitacora, TO_CHAR(fecha_evento, 'DD-MM-YYYY HH24:MI') AS fecha,
       usuario_bd, detalle
FROM bitacora_citas
ORDER BY id_bitacora DESC
FETCH FIRST 3 ROWS ONLY;

-- Total de registros en la bitacora.
SELECT COUNT(*) AS total_bitacora FROM bitacora_citas;


-- =====================================================================
-- 11. VERIFICACION FINAL DE VOLUMENES
-- =====================================================================
-- Consulta de cierre: muestra los totales de las tablas principales
-- despues de ejecutar los objetos y sus validaciones.
-- =====================================================================

DECLARE
    v_pacientes   NUMBER;
    v_medicos     NUMBER;
    v_citas       NUMBER;
    v_stock       NUMBER;
    v_bitacora    NUMBER;
    v_recetas     NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_pacientes FROM paciente;
    SELECT COUNT(*) INTO v_medicos   FROM medico;
    SELECT COUNT(*) INTO v_citas     FROM cita;
    SELECT NVL(SUM(stock), 0) INTO v_stock FROM medicamento;
    SELECT COUNT(*) INTO v_bitacora  FROM bitacora_citas;
    SELECT COUNT(*) INTO v_recetas   FROM receta_detalle;

    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE(' RESUMEN FINAL DE VOLUMENES');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('Pacientes                 : ' || v_pacientes);
    DBMS_OUTPUT.PUT_LINE('Medicos                   : ' || v_medicos);
    DBMS_OUTPUT.PUT_LINE('Citas (estado final)      : ' || v_citas);
    DBMS_OUTPUT.PUT_LINE('Stock total de medicamentos: ' || v_stock);
    DBMS_OUTPUT.PUT_LINE('Detalles de receta        : ' || v_recetas);
    DBMS_OUTPUT.PUT_LINE('Registros en bitacora     : ' || v_bitacora);
    DBMS_OUTPUT.PUT_LINE('==============================================');
END;
/

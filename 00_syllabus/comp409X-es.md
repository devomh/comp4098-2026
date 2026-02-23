# UNIVERSIDAD DE PUERTO RICO EN HUMACAO
## DEPARTAMENTO DE MATEMÁTICAS

**A. Encabezado:** Universidad de Puerto Rico en Humacao
**B. Nombre del curso:** Gestión de Datos y Arquitecturas para Ciencia de Datos
**C. Codificación:** COMP409X
**D. Cantidad de horas/créditos:** Tres (3) horas contacto¹ / Tres (3) créditos
**E. Requisitos o correquisitos y otros requerimientos:** COMP4097

### F. Descripción del curso
Este curso transiciona desde los sistemas tradicionales de bases de datos hacia la ingeniería de datos moderna y las arquitecturas orientadas a Ciencia de Datos. El estudiante avanzará más allá de los mecanismos básicos de almacenamiento para dominar las arquitecturas que impulsan la analítica moderna y la inteligencia artificial. El currículo contrasta sistemas transaccionales (OLTP) con motores analíticos (OLAP), cerrando la brecha entre el almacenamiento de datos crudos y la generación de conocimiento accionable. Mediante la exploración de un stack de persistencia políglota —incluyendo bases de datos relacionales, motores analíticos columnares, almacenes documentales y bases de datos vectoriales— el estudiante aprenderá a construir sistemas que manejen datos estructurados, semi-estructurados y no estructurados (texto/embeddings) esenciales para aplicaciones de inteligencia artificial como Retrieval-Augmented Generation (RAG).

### G. Objetivos de aprendizaje
Al finalizar el semestre el estudiante podrá:
1. Distinguir y construir sistemas de datos seleccionando el motor de almacenamiento adecuado (orientado a filas vs. orientado a columnas) según los requerimientos de carga de trabajo (OLTP vs. OLAP).
2. Dominar SQL analítico avanzado, superando las operaciones CRUD básicas para realizar análisis complejos mediante Window Functions, CTEs y agregaciones de alto rendimiento.
3. Gestionar diversas formas de datos utilizando modelos relacionales, documentales y clave-valor.
4. Implementar acceso seguro y de producción a datos mediante capas de acceso (DAL), patrones DAO y Repository, ORMs, y técnicas de prevención de inyección SQL y gestión segura de credenciales.
5. Construir pipelines de datos para inteligencia artificial integrando bases de datos vectoriales y embeddings para búsqueda semántica y sistemas de Retrieval-Augmented Generation (RAG).

### H. Bosquejo de contenido y distribución del tiempo

#### Módulo 1: Fundamentos Relacionales y SQL Transaccional (12 horas)
*Enfoque: Dominio del modelo relacional, integridad de datos y el lenguaje de las bases de datos estándar.*

**I. Fundamentos de la gestión de datos** (3 horas)
   1. Introducción y el ciclo de vida de los datos
      a) Panorama del curso y configuración de herramientas (Google Colab)
      b) El ciclo de vida de los datos: captura, almacenamiento, procesamiento, análisis, archivo
      c) Propiedades ACID y su rol en el ciclo de vida
   2. El modelo relacional
      a) Relaciones, tuplas, atributos, dominios
      b) Llaves: superllave, candidata, primaria, foránea
      c) Integridad referencial

**II. Modelado conceptual y lógico** (3 horas)
   1. Modelado Entidad-Relación (E-R)
      a) Entidades y atributos (compuestos, multivalorados, derivados)
      b) Relaciones y cardinalidad (1:1, 1:N, M:N)
      c) Entidades fuertes vs. débiles
      d) Empleo de diagramas E-R
   2. Diseño lógico (de E-R a relacional)
      a) Reducción de entidades fuertes y débiles a tablas
      b) Mapeo de relaciones 1:N y M:N
      c) Manejo de atributos multivalorados
      d) Contexto de normalización

**III. Normalización y calidad de datos** (3 horas)
   1. Teoría de normalización (1FN – 3FN)
      a) Anomalías de inserción, eliminación y actualización
      b) Dependencias funcionales
      c) Primera forma normal (atomicidad)
      d) Segunda forma normal (dependencias parciales)
      e) Tercera forma normal (dependencias transitivas)
   2. Diseño práctico y desnormalización
      a) Cuándo detener la normalización
      b) Rendimiento de escritura vs. rendimiento de lectura
      c) Compromisos de la normalización en flujos de Ciencia de Datos

**IV. SQL Transaccional (PostgreSQL)** (3 horas)
   1. DDL e implementación de esquemas
      a) Arquitectura de PostgreSQL
      b) Tipos de datos
      c) `CREATE`, `ALTER`, `DROP`
      d) Restricciones (`NOT NULL`, `UNIQUE`, `CHECK`, `FOREIGN KEY`)
   2. DML, consultas básicas y transacciones
      a) `INSERT`, `UPDATE`, `DELETE`
      b) `SELECT` básico con `WHERE`, `ORDER BY`
      c) Control de transacciones: `BEGIN`, `COMMIT`, `ROLLBACK`
      d) Transacciones como mecanismo de integridad en operaciones de ingestión y actualización de datos

#### Módulo 2: SQL Analítico y Arquitectura (12 horas)
*Enfoque: Análisis de datos de alto rendimiento, almacenamiento columnar y SQL complejo.*

**V. Arquitecturas analíticas** (3 horas)
   1. OLTP vs. OLAP
      a) Almacenamiento orientado a filas vs. orientado a columnas
      b) Compresión y vectorización en almacenes columnares
   2. Introducción a DuckDB
      a) Motor OLAP in-process
      b) Lectura de datos desde CSV/Parquet
      c) Comparación con PostgreSQL

**VI. Técnicas avanzadas de SQL I** (3 horas)
   1. Joins complejos
      a) `INNER`, `LEFT`, `RIGHT`, `FULL OUTER JOIN`
      b) Lógica de joins múltiples
   2. Agregación y agrupamiento
      a) `GROUP BY`, `HAVING`
      b) Funciones de agregación (`COUNT`, `SUM`, `AVG`)

**VII. Técnicas avanzadas de SQL II** (3 horas)
   1. Funciones analíticas (Window Functions)
      a) `OVER`, `PARTITION BY`, `ORDER BY`
      b) Funciones de ranking: `RANK`, `DENSE_RANK`, `ROW_NUMBER`
   2. CTEs y analítica avanzada
      a) Common Table Expressions (CTEs)
      b) Funciones de desplazamiento: `LEAD`, `LAG`
      c) Crecimiento interanual y promedios móviles

**VIII. Laboratorio de rendimiento** (3 horas)
   1. Preparación del laboratorio
      a) Estrategias de generación de datos
      b) Carga de datasets masivos (10M+ filas)
   2. Benchmark de rendimiento
      a) Análisis conceptual de planes de ejecución
      b) Medición de tiempos de ejecución
      c) Experimento comparativo: PostgreSQL vs. DuckDB con consultas analíticas sobre 10M+ filas

#### Módulo 3: NoSQL y Modelos de Datos Flexibles (6 horas)
*Enfoque: Gestión de datos que no se ajustan al modelo tabular.*

**IX. Conceptos distribuidos y documentos** (3 horas)
   1. El teorema CAP
      a) Consistencia, disponibilidad, tolerancia a particiones
      b) Schema-on-Read vs. Schema-on-Write
   2. Almacenes documentales (MongoDB)
      a) Modelado de datos jerárquicos en JSON
      b) Consulta de documentos anidados
      c) Comparación: modelado en JSON vs. tablas

**X. MongoDB en la práctica** (3 horas)
   1. Fundamentos de MongoDB
      a) Configuración de MongoDB Atlas
      b) Operaciones CRUD básicas (`find`, `insert`, `update`, `delete`)
   2. Consultas avanzadas sobre documentos
      a) Consultas sobre arreglos y estructuras anidadas
      b) Pipeline de agregación

#### Módulo 4: Seguridad y Acceso a Datos (6 horas)
*Enfoque: Acceso seguro y robusto desde la aplicación a la base de datos.*

**XI. Almacenes clave-valor y seguridad de datos** (3 horas)
   1. Redis: conceptos y práctica
      a) Almacenes clave-valor y estrategias de caching
      b) Estructuras de datos de Redis
      c) Implementación de una capa de caché
   2. Inyección SQL y conectividad segura
      a) SQL Injection como vector de ataque (OWASP Top 10)
      b) Consultas parametrizadas (parameterized queries) como defensa
      c) Gestión segura de credenciales: variables de entorno, archivos `.env`, connection strings

**XII. La capa de acceso a datos (DAL)** (3 horas)
   1. Arquitectura y conectividad
      a) Separación de responsabilidades (Separation of Concerns)
      b) La capa de acceso a datos (DAL / Persistence Layer)
      c) Independencia del motor de base de datos
      d) Gestión de conexiones: drivers, connection strings, Connection Pooling
      e) Redis como capa de caché dentro del DAL
   2. Patrones de implementación
      a) Patrón DAO (Data Access Object)
      b) Patrón Repository
      c) ORM (Object-Relational Mapping) con SQLAlchemy
      d) Comparación: SQL crudo vs. ORM/DAO

#### Módulo 5: Arquitecturas Modernas e Inteligencia Artificial (6 horas)
*Enfoque: El "AI Stack" — búsqueda vectorial y RAG.*

**XIII. Datos no estructurados y bases de datos vectoriales** (3 horas)
   1. Datos no estructurados y embeddings
      a) Manejo de datos textuales y binarios
      b) Qué son los embeddings (vectores de alta dimensionalidad)
      c) Visualización de similitud vectorial
   2. Búsqueda por similitud vectorial
      a) Similitud coseno, distancia euclidiana
      b) Almacenes vectoriales: ChromaDB / LanceDB

**XIV. Arquitectura RAG** (3 horas)
   1. Conceptos de RAG
      a) Retrieval-Augmented Generation: principios y arquitectura
      b) Conexión de una base de datos vectorial con un LLM
   2. Construcción de un sistema RAG
      a) Indexación, recuperación, generación
      b) Construcción del backend (ingestión y recuperación)
      c) Conexión de la capa de recuperación con el LLM
      d) Afinamiento de resultados

*Las tres (3) horas restantes se han de utilizar para impartir evaluaciones en el salón de clase.*

---

¹ Una hora contacto equivale a cincuenta (50) minutos.

### I. Estrategias Instruccionales
Para lograr los objetivos del curso se realizarán actividades tales como: conferencias interactivas, laboratorios prácticos, demostraciones en vivo, trabajos colaborativos, estudios independientes, discusión de asignaciones y presentación de proyectos.

### J. Recursos mínimos disponibles o requeridos
La Universidad debe proveer acceso a Internet y un proyector o pantalla para demostraciones en clase. El curso utiliza exclusivamente herramientas de código abierto y servicios gratuitos: Google Colab como entorno de ejecución, PostgreSQL y DuckDB como motores de bases de datos, MongoDB Atlas (capa gratuita) como base de datos documental, Redis (capa gratuita o contenedor local) como almacén clave-valor, y ChromaDB o LanceDB como bases de datos vectoriales. No se requieren licencias de programados comerciales.

### K. Técnicas de evaluación
Para lograr los objetivos del curso se ofrecerán por lo menos dos exámenes parciales (con un peso de 50% de la nota final), una de las opciones siguientes: asignaciones de programación individual o examen parcial (con un peso de 25% de la nota final). Además de los exámenes parciales, es requisito del curso el diseño e implementación de un proyecto final integrador (con un peso de 25% de la nota final). Se sugiere que el proyecto final integre conocimientos de todos los módulos del curso: SQL relacional, NoSQL, bases de datos vectoriales y conexión con un modelo de lenguaje (LLM).

### L. Acomodo razonable
Los estudiantes que requieran acomodo razonable deben visitar la Oficina de Servicios para la Población con Impedimentos (SERPI) y comunicarse con el profesor al inicio del semestre para planificar el acomodo necesario conforme a las recomendaciones de SERPI.

### M. Integridad académica
El Artículo 6.2 del Reglamento General de Estudiantes de la UPR (Certificación Número. 13, 2009-2010 de la Junta de Síndicos) establece que "la deshonestidad académica incluye, pero no se limita a: acciones fraudulentas, la obtención de notas o grados académicos valiéndose de falsas o fraudulentas simulaciones, copiar total o parcialmente la labor académica de otra persona, plagiar total o parcialmente el trabajo de otra persona, copiar total o parcialmente las respuestas de otra persona a las preguntas de un examen, haciendo o consiguiendo que otro tome en su nombre cualquier prueba o examen oral o escrito, así como la ayuda o facilitación para que otra persona incurra en la referida conducta".

Cualquiera de estas acciones estará sujeta a sanciones disciplinarias en conformidad con el procedimiento disciplinario establecido en dicho reglamento.

### N. Normativa sobre discrimen por sexo y género en modalidad de violencia sexual
"La Universidad de Puerto Rico prohíbe el discrimen por razón de sexo y género en todas sus modalidades, incluyendo el hostigamiento sexual. Según la Política Institucional contra Hostigamiento Sexual, Certificación Núm. 130 (2014-15) de la Junta de Gobierno, si un(a) estudiante es o está siendo afectado por conductas relacionadas a hostigamiento sexual, puede acudir a la Oficina de la Procuraduría Estudiantil, el Decanato de Estudiantes o la Coordinadora de Cumplimiento con Titulo IX para orientación y/o para presentar una queja".

### O. Sistema de calificación
La nota se adjudicará a base de la siguiente escala (porcentual):
100 - 90 A; 89 - 80 B; 79 - 70 C; 69 - 60 D; 59 – 0 F

### P. Bibliografía
1. Watt, A. & Eng, N. (2014). *Database Design*, 2nd Ed. BCcampus Open Education. Disponible en: https://opentextbc.ca/dbdesign01/
2. Silberschatz, A., Korth, H. F. & Sudarshan, S. (2019). *Database System Concepts*, 7th Ed. McGraw Hill
3. PostgreSQL Global Development Group. *PostgreSQL Documentation*. Disponible en: https://www.postgresql.org/docs/
4. DuckDB Foundation. *DuckDB Documentation*. Disponible en: https://duckdb.org/docs/
5. MongoDB, Inc. *MongoDB Manual*. Disponible en: https://www.mongodb.com/docs/manual/
6. Redis Ltd. *Redis Documentation*. Disponible en: https://redis.io/docs/
7. ChromaDB. *Chroma Documentation*. Disponible en: https://docs.trychroma.com/

### Q. Créditos

Primera versión por Dr. Ollantay Medina Huamán con el insumo de Dr. Elio Ramos Colón, Profa. Idalyn Ríos Díaz y Prof. José O. Sotero Esteva, febrero de 2026.

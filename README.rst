observarble
===========

*NOTE:* Use `-d:debugObservarble` to see macro output

1. Basic usage
--------------

.. code-block:: nim

    observarble MyObserverable1:
        field1* string
        field2 int


Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble1* = ref object of Observarble
            p_field1: string
            p_field2: string

    proc field1(o186002: MyObservarble): string =
        o186002.p_field1

    proc `field1=`(o186004: MyObservarble; field1: string) =
        o186004.p_field1 = field1
        o186004.notify()

    proc field2*(o186006: MyObservarble): string =
        o186006.p_field2

    proc `field2=`*(o186008: MyObservarble; field2: string) =
        o186008.p_field2 = field2
        o186008.notify()


2. Mark some fields non-observarble
-----------------------------------

.. code-block:: nim

    observarble MyObserverable3:
        field1* string
        field2 int {disabled: true}
        field3* int {disabled: true}

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObserverable3* = ref object of Observarble
            p_field1: string
            field2: int
            field3*: int

        proc field1*(o186032: MyObserverable2): string =
            o186032.p_field1

        proc `field1=`*(o186034: MyObserverable2; field1: string) =
            o186034.p_field1 = field1
            o186034.notify()


3. Set custom getter or setter

.. code-block:: nim

    observarble MyObserverable4:
        field1* string
        field2 string {
            getter: proc(o: MyObserverable4): string =
                result = o.field1 & o.field2
        }
        field3* string {
            getter: proc(o: MyObserverable4, v: string) =
                o.field1 = v
                o.field2 = v
                o.notify()
        }

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObserverable4* = ref object of Observarble
            p_field1: string
            p_field2: string
            p_field3: string

    proc field1*(o186092: MyObserverable4): string =
        o186092.p_field1

    proc `field1=`*(o186094: MyObserverable4; field1: string) =
        o186094.p_field1 = field1
        o186094.notify()

    proc field2(o: MyObserverable4): string =
        result = o.field1 & o.field2

    proc `field2=`(o186098: MyObserverable4; field2: string) =
        o186098.p_field2 = field2
        o186098.notify()

    proc field3*(o: MyObserverable4; v: string) =
        o.field1 = v
        o.field2 = v
        o.notify()

    proc `field3=`*(o186102: MyObserverable4; field3: string) =
        o186102.p_field3 = field3
        o186102.notify()


4. Inherits observarble type

.. code-block:: nim

    observarble MyObservarble5 of MyObservarble1:
        field3* string

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble5* = ref object of MyObservarble1
            p_field3: string

    proc field3*(o186136: MyObservarble5): string =
        o186136.p_field3

    proc `field3=`*(o186138: MyObservarble5; field3: string) =
        o186138.p_field3 = field3
        o186138.notify()


5. Set set of observarble fields

.. code-block:: nim

    observarble MyObservarble6:
        {field1, field4}

        field1* string
        field2 int
        field3* int
        field4* int
        field5* int


Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble6* = ref object of Observarble
            p_field1: string
            field2: int
            field3*: int
            p_field4: int
            field5*: int

    proc field1*(o186002: MyObservarble6): string =
        o186002.p_field1

    proc `field1=`*(o186004: MyObservarble6; field1: string) =
        o186004.p_field1 = field1
        o186004.notify()

    proc field4*(o186014: MyObservarble6): int =
        o186014.p_field4

    proc `field4=`*(o186016: MyObservarble6; field4: int) =
        o186016.p_field4 = field4
        o186016.notify()
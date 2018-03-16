import observarble


observarble MyObservarble1:
    field1 string
    field2* string


observarble MyObserverable2:
    field1* string
    field2 int {disabled: true}
    field3* int {disabled: true}


observarble MyObserverable3:
    field1* string
    field2 string {disabled: true}
    field3* string {disabled: true}


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


observarble MyObservarble5 of MyObservarble1:
    field3* string


observarble MyObservarble6:
    {field1, field4}

    field1* string
    field2 int
    field3* int
    field4* int
    field5* int
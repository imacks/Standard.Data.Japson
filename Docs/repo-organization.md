Repo Organization
=================
Our repo relies heavily on templates and automation tools/scripts. This means a lot of content in the repo is generated for viewing only. With certain exceptions as explained below, you will either make changes to templates or the template data bindings.

Folder Structure
================
Our repos are constructed and maintained using [PowerBuild](https://lizoc.github.io/powerbuild). For example, a C# repo will have a structure that resembles this:

```
README.md
LICENSE.txt
THIRD-PARTY-LICENSE.txt
Build.cmd
build.sh
Docs/
    README.md
    ...
    conceptual/
        ...
    api/
        ...
Credential/
    EcmaPrivateKey.snk
    EcmaPublicKey.snk
    ...
Source/
    global.bsd
    BuildOrder.ini
    buildnum.ini
    myproject1
        project.bsd
        Embed/
            ...
        Properties
            StringData.csv
        Source/
            Class1.cs
            ...
        Templates/
            mytemplate.pstmpl
            ...
        Resources/
            ...
    myproject1.Tests
        project.bsd
        Embed/
            ...
        Properties
            StringData.csv
        Source/
            Class1.cs
            ...
        Templates/
            mytemplate.pstmpl
            ...
        Resources/
            ...
Tools/
    DotNetCore/
        ...
    BuildScript/
        ...
    PowerBuild/
        ...
```


*Last updated on 16 May, 2017*

env {
  repoPath = 'E:/projects/lizoc/standard.data.japson/master'
  credentialPath = ${env.repoPath}'/Credential/EcmaPrivateKey.snk'
}
myData {
  year = 2017
  corpName = Lizoc
  corpNameToLower = lizoc 
  corpFullName = Lizoc Inc
  copyright = Copyright © ${myData.year} ${myData.corpFullName}. All rights reserved.
}
project {
  info {
    name = Lizoc.PowerShell.Commands.Japson
    nameToLower = lizoc.powershell.commands.japson
    tags = [ 'lizoc', 'powershell', 'commands', 'japson' ]
    family = Lizoc.PowerShell
    familyToLower = lizoc.powershell
    description = """The JAPSON format is a JSON superset. It mainly focuses on human-friendly editing using non-specialized text editors."""
    authors = [ ${myData.corpName}, 'LizocDev' ]
    showLicense = false
    docUrl = 'http://lizoc.github.io/'${project.info.familyToLower}
    sourceUrl = 'http://www.github.com/'${project.info.familyToLower}
  }
  version {
    major = 1
    minor = 1
    build = 10332
    revision = 0
    suffix = '-beta'
    full = ${project.version.major}.${project.version.minor}.${project.version.build}.${project.version.revision}${project.version.suffix}
  }
  build {
    embedInteropTypes = false
    optimize = true
    publicSign = false
    language = en-US
    compiler = csc
    isExecutable = false
    debugType = full
    strict = true
    nowarn = [ 'CS1591', 'CS0168' ]
    unsafe = true
    platform = AnyCpu
    langVersion = '6'
    makeDoc = true
    delaySign = false
    files {
      compile {
        include = [
          'Properties/**/.cs'
          'Source/**/.cs'         
        ]
      }
      embed {
        includeRoot = [
          'Embed/**'
        ]
      }
      static {
        includeRoot = [
          'Resources/**'
        ]
      }
    }
  }
  dependency {
    'Standard.Data.Japson' {
      target = project
    }
  }
  conditions {
    'configuration = debug' {
      build {
        optimize = false
        define = [ 'TRACE', 'DEBUG' ]
      }
    }
    'configuration = release' {
      build {
        optimize = false
        define = [ 'TRACE' ]
        keyFile = ${env.credentialPath}
      }
    }
    'framework = netstandard1.4' {
      imports = [ 'net40' ]
      dependency {
        'Microsoft.PowerShell.5.ReferenceAssemblies' = '1.0.0-*'
        'Microsoft.NETCore' = '5.0.1-*'
        'Microsoft.NETCore.Portable.Compatibility' = '1.0.1-*'
      }
      analyzerOptions {
        languageId = cs
      }
      build {
        compilerArgs = []
        define = [ "NETSTANDARD", "NETSTANDARD1_4" ]
      }
    }
  }
}




name = ${project.name}
title = ${name}
copyright = Copyright © ${myData.year} ${myData.corpFullName}. All rights reserved.
description = ${project.description}
version = ${project.version.major}.${project.version.minor}.${project.version.build}.${project.version.revision}${project.version.suffix}
embedInteropTypes = ${project.config.embedInteropTypes}
authors = [ ${myData.corpName}, ${project.authors} ]
language = ${project.config.language}
buildOptions {
  compilerName = ${project.config.compiler}
}
configurations {
  debug {
    buildOptions {
      optimize = false
      publicSign = false
      define = [ 'TRACE', 'DEBUG' ]
    }
  }
  release {
    buildOptions {
      optimize = true
      publicSign = true
      define = [ 'TRACE' ]
      keyFile = ${env.credentialPath}
    }
  }
}
packOptions {
  summary = ${project.description}
  tags = [ ${myData.corpNameToLower}, ${project.nameSplit} ]
  owners = ${authors}
  releaseNotes = ${project.docUrl}'/releasenotes'
  iconUrl = ${project.docUrl}'/icon.png'
  projectUrl = ${project.sourceUrl}
  licenseUrl = ${project.docUrl}'/license'
  requireLicenseAcceptance = ${project.showLicense}
  repository {
    type = git
    url = ${project.sourceUrl}
  }
  files {
    mappings {
      '/' {
        includeFiles = [
          ${env.repoPath}'/LICENSE.txt'
          ${env.repoPath}'/THIRD-PARTY-LICENSE.txt'
        ]
      }
    }
  }
}
dependencies = ${project.dependency}
frameworks = ${project.frameworks}


{
  "name": "Lizoc.PowerShell.Commands.Japson",
  "title": "Lizoc.PowerShell.Commands.Japson",
  "copyright": "Copyright © 2016 Lizoc Inc. All rights reserved.",
  "description": "Lizoc PowerShell Utility (JAPSON)",
  "version": "1.1.{{$BuildNumber}}.0-beta",
  "embedInteropTypes": false,
  "authors": [
    "Lizoc"
  ],
  "language": "en-US",
  "buildOptions": {
    "compilerName": "csc"
  },
  "configurations": {
    "Debug": {
      "buildOptions": {
        "optimize": false,
        "publicSign": false,
        "define": ["TRACE", "DEBUG"]
      }
    },
    "Release": {
      "buildOptions": {
        "optimize": true,
        "publicSign": true,
        "keyFile": "{{$RepoRelativeDir}}/Credential/EcmaPrivateKey.snk",
        "define": ["TRACE"]
      }
    }
  },
  "packOptions": {
    "summary": "Lizoc PowerShell Utility (JAPSON)",
    "tags": ["lizoc", "japson", "powershell", "cmdlet"],
    "owners": ["lizoc"],
    "releaseNotes": "Initial release.",
    "iconUrl": "http://lizoc.github.io/standard.data.japson/icon.png",
    "projectUrl": "http://www.github.com/lizoc/standard.data.japson",
    "licenseUrl": "http://lizoc.github.io/standard.data.japson/license",
    "requireLicenseAcceptance": false,
    "repository": {
        "type": "git",
        "url": "http://github.com/lizoc/standard.data.japson"
    },
    "files": {
      "mappings": {
        "/": {
          "includeFiles": [
            "{{$RepoRelativeDir}}/LICENSE.txt",
            "{{$RepoRelativeDir}}/THIRD-PARTY-LICENSE.txt"
          ]
        }
      }
    }
  },
  "frameworks": {
    "netstandard1.4": {
      "buildOptions": {
        "additionalArguments": [],
        "define": ["NETSTANDARD", "NETSTANDARD1_4"],
        "compile": {
          "include": [
            "Properties/**/.cs",
            "Source/**/.cs"
          ]
        },
        "embed": {
          "include": [
            "Embed/**"
          ]
        },
        "copyToOutput": {
          "include": [
            "Resources/**"
          ]
        },
        "nowarn": [
          "CS1591",
          "CS0168"
        ],
        "emitEntryPoint": false,
        "debugType": "full",
        "warningsAsErrors": true,
        "allowUnsafe": true,
        "preserveCompilationContext": false,
        "platform": "AnyCpu",
        "languageVersion": "6",
        "xmlDoc": true,
        "delaySign": false,
        "compilerName": "csc"
      },
      "analyzerOptions": {
        "languageId": "cs"
      },
      "frameworkAssemblies": {},
      "dependencies": {
        "Microsoft.PowerShell.5.ReferenceAssemblies": "1.0.0-*",
        "Microsoft.NETCore": "5.0.1-*",
        "Microsoft.NETCore.Portable.Compatibility": "1.0.1-*",
        "Standard.Data.Japson": {
          "target": "project"
        }
      },
      "imports": ["net40"]
    }
  }
}

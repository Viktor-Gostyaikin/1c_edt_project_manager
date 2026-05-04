# Менеджер подготовки окружения рабочего места разработчика

В данном репозитории хранятся скрипты для проверки и установки зависимотей окружения проекта.

Для начала работы склонируйте или скачайте этот репозиторий в локальное рабочее пространство.

## Порядок выполнения для Windows

```
Проверялось на Win11
```

### Заполнить локальные переменные 
Изменить файл локальных переменных через текстовый редактор.
```
init_workspace/windows/local.vars.ps1
```


Для примера использовать следющий файл.

```
init_workspace/windows/local.vars.example.ps1
```

**Описание важных переменных. **
`OneCUser`, `OneCPassword` - данные доступа к ```https://releases.1c.ru/```
`GitUserName` - Фамили и имя сотрудника
`GitUserEmail` - корпоративный email
`GitLabHost` - домен корпоративного GitLab

Остальные можно оставить по умолчанию как в примере.

### Запуск проверки установленных зависимостей
```cmd
check-quickstart-deps.cmd
```

### Установка Git клиента

```cmd
init_workspace/windows/install-git.cmd
```

### Настройка ssh доступа к удаленному репозиторию
Выполняется ручная установка. См. init_workspace/windows/Настройка Git-клиента на Windows.md

Для проверки
```cmd
init_workspace/windows/check-ssh-gitlab.cmd
```

### Установка платформы 1С:Предприятие

```cmd
init_workspace/windows/install-platform.cmd
```

### Установка 1C:EDT

```cmd
init_workspace/windows/install-edt.cmd
```

## Порядок выполнения для Linux

MVP Linux-версии находится в:

```bash
init_workspace/linux
```

Создайте локальные переменные:

```bash
cp init_workspace/linux/local.vars.example.sh init_workspace/linux/local.vars.sh
```

Заполните `local.vars.sh`, затем запустите терминальный мастер:

```bash
cd init_workspace/linux
./start-workspace-setup.sh
```

Автоматическая установка платформы 1С и 1C:EDT для Linux пока не входит в MVP. Их нужно установить вручную из дистрибутивов `releases.1c.ru`, после чего запустить проверку:

```bash
./commands/check-quickstart-deps.sh
```

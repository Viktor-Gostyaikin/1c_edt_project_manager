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

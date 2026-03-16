#include "mainwindow.h"

#include <QApplication>
#include <QLabel>
#include <QPushButton>
#include <QMessageBox>

void clickEvent();

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    QWidget widget;
    widget.setWindowTitle("ЧТП чат");
    widget.setMinimumHeight(425);
    widget.setMinimumWidth(625);

    QLabel label{&widget};
    label.setText("Это самый лучший мессенджер на свете");

    QPushButton btn{"Пойти нахуй", &widget};
    QObject::connect(&btn, &QPushButton::clicked, clickEvent);

    widget.show();
    return a.exec();
}

void clickEvent()
{
    QMessageBox msgBox;
    msgBox.setText("ты идешь нахой!");
    msgBox.exec();
}

#include "mainwindow.h"

#include <QApplication>
#include <QLabel>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    QWidget widget;
    widget.setWindowTitle("ЧТП чат");
    widget.setMinimumHeight(425);
    widget.setMinimumWidth(625);

    QLabel label{&widget};
    label.setText("Это самый лучший мессенджер на свете");

    widget.show();
    return a.exec();
}
